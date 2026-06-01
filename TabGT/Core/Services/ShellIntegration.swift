import Foundation

/// Injects OSC 7 cwd reporting so SwiftTerm can keep the workspace browser in sync,
/// and OSC 9001 tabgt-git sequences so the Inspector can show live git repo state.
/// Works for both bash (via PROMPT_COMMAND) and zsh (via precmd_functions + ZDOTDIR).
enum ShellIntegration {
    private static let unixOscFunction = #"__tabgt_osc7(){ printf "%b" $'\033]7;file://'"$(pwd)"$'\033\\'; }"#

    // Runs after each prompt: collects git info and sends OSC 9001;tabgt-git sequences.
    // Single-line so it is safe to pass as an SSH remote command argument.
    private static let unixGitFunction = #"__tabgt_git(){ local b s=0 m=0 u=0 a=0 be=0; b=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || { printf '\033]9001;tabgt-git;no-repo;\007'; return; }; while IFS= read -r l; do x="${l:0:2}"; [[ "${x:0:1}" != " " && "${x:0:1}" != "?" ]] && (( s++ )); [[ "${x:1:1}" == "M" || "${x:1:1}" == "D" ]] && (( m++ )); [[ "$x" == "??" ]] && (( u++ )); done <<< "$(git status --porcelain 2>/dev/null)"; local ab; ab=$(git rev-list --left-right --count @{u}...HEAD 2>/dev/null); [[ -n "$ab" ]] && { be=${ab%%$'\t'*}; a=${ab##*$'\t'}; }; local h msg; h=$(git log -1 --format="%h" 2>/dev/null); msg=$(git log -1 --format="%s" 2>/dev/null); printf '\033]9001;tabgt-git;branch;%s\007' "$b"; printf '\033]9001;tabgt-git;status;%s\007' "${s}:${m}:${u}"; printf '\033]9001;tabgt-git;ahead-behind;%s\007' "${a}:${be}"; [[ -n "$h" ]] && printf '\033]9001;tabgt-git;commit;%s\007' "${h}:${msg}"; }"#

    static func unixRemoteLaunchCommand(directory: String?, shell: String?) -> String {
        let shellExpr = shell ?? "\"$SHELL\""
        let hookBody = unixHookBootstrap(shellExpr: shellExpr)
        let quotedHooks = singleQuotedShellArgument(hookBody)

        // Run TabGT hooks inside bash when available; always launch the login shell even if hooks fail.
        // Without the bash wrapper, hook syntax breaks on /bin/sh and the SSH session closes immediately.
        var launch = "if command -v bash >/dev/null 2>&1; then bash -lc '\(quotedHooks); exec \(shellExpr) -l'; else exec \(shellExpr) -l; fi"

        if let directory {
            let escaped = directory.replacingOccurrences(of: "'", with: "'\\''")
            launch = "cd '\(escaped)' 2>/dev/null || true; \(launch)"
        }

        return launch
    }

    /// Bash-only hook setup injected before `exec $SHELL -l`. Each step is best-effort so a missing
    /// dependency (python3, git, etc.) never prevents the interactive shell from starting.
    private static func unixHookBootstrap(shellExpr: String) -> String {
        // Write hook functions to a file so both bash and zsh can source it.
        let hookScript = "\(unixGitFunction)\n\(unixOscFunction)\n"
        let hookB64 = Data(hookScript.utf8).base64EncodedString()
        let writeHook = "python3 -c \"import base64,os; t=os.path.expanduser('~/.tabgt'); os.makedirs(t,exist_ok=True); open(t+'/tabgt-shell-hooks.sh','w').write(base64.b64decode('\(hookB64)').decode())\" 2>/dev/null || true"

        let bashHooks = #"export -f __tabgt_osc7 __tabgt_git 2>/dev/null; export PROMPT_COMMAND="__tabgt_osc7; __tabgt_git${PROMPT_COMMAND:+;$PROMPT_COMMAND}""#
        let zshHooks = "_td=$(mktemp -d) && python3 -c \"import os; d,h=os.path.expanduser('~'),os.environ.get('ZDOTDIR',os.path.expanduser('~')); td=os.environ['_td']; open(td+'/.zprofile','w').write('[ -f \\\"'+h+'/.zprofile\\\" ] && ZDOTDIR=\\\"\\\" source \\\"'+h+'/.zprofile\\\"\\n'); open(td+'/.zshrc','w').write('[ -f \\\"'+h+'/.zshrc\\\" ] && ZDOTDIR=\\\"\\\" source \\\"'+h+'/.zshrc\\\"\\nsource ~/.tabgt/tabgt-shell-hooks.sh 2>/dev/null\\nprecmd_functions+=(__tabgt_git)\\n'); open(td+'/.zlogin','w').write('[ -f \\\"'+h+'/.zlogin\\\" ] && ZDOTDIR=\\\"\\\" source \\\"'+h+'/.zlogin\\\"\\n')\" 2>/dev/null && export ZDOTDIR=\"$_td\" || true"
        let hookSetup = "case \"\(shellExpr)\" in *zsh*) \(zshHooks) ;; *) \(bashHooks) ;; esac"

        return [
            unixOscFunction,
            unixGitFunction,
            writeHook,
            "__tabgt_osc7 2>/dev/null",
            "__tabgt_git 2>/dev/null",
            hookSetup
        ].joined(separator: "; ")
    }

    /// Escapes `value` for embedding inside a single-quoted POSIX shell argument.
    private static func singleQuotedShellArgument(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "'\\''")
    }

    static func windowsRemoteLaunchCommand(directory: String?, shell: String?) -> String? {
        let resolvedShell = shell ?? "powershell"
        let lower = resolvedShell.lowercased()

        if lower.hasSuffix("cmd.exe") || lower == "cmd" {
            guard let directory else { return nil }
            let escaped = directory.replacingOccurrences(of: "\"", with: "\\\"")
            return "cmd /k \"cd /d \\\"\(escaped)\\\"\""
        }

        // PowerShell: inject git hooks via base64-encoded command so quoting is never an issue.
        // The profile ($PROFILE / Oh My Posh) loads first because -NoExit triggers interactive
        // mode, then our encoded command runs and wraps the existing prompt function.
        var lines: [String] = []
        if let directory {
            let escaped = directory.replacingOccurrences(of: "'", with: "''")
            lines.append("Set-Location -LiteralPath '\(escaped)'")
        }
        lines.append(psGitHookScript)
        let encoded = encodeForPowerShell(lines.joined(separator: "\n"))
        return "\(resolvedShell) -NoExit -EncodedCommand \(encoded)"
    }

    // MARK: - PowerShell git hooks

    private static var psGitHookScript: String {
        """
        function global:__tabgt_git {
            $p = git status --short --branch --porcelain=v2 2>$null
            if ($LASTEXITCODE -ne 0 -or $null -eq $p) {
                [Console]::Write([char]27 + ']9001;tabgt-git;no-repo;' + [char]7); return
            }
            $b      = $p | Where-Object { $_ -match '^# branch\\.head (.+)' } | ForEach-Object { $Matches[1] } | Select-Object -First 1; if (-not $b) { $b = '(detached)' }
            $ahead  = $p | Where-Object { $_ -match '^# branch\\.ab \\+(\\d+)' } | ForEach-Object { $Matches[1] } | Select-Object -First 1; if (-not $ahead)  { $ahead  = '0' }
            $behind = $p | Where-Object { $_ -match '^# branch\\.ab \\+\\d+ -(\\d+)' } | ForEach-Object { $Matches[1] } | Select-Object -First 1; if (-not $behind) { $behind = '0' }
            $st = @($p | Where-Object { $_ -match '^[12u] [^\\.][^ ]' }).Count
            $mo = @($p | Where-Object { $_ -match '^[12u] \\.[M]' }).Count
            $u  = @($p | Where-Object { $_ -match '^\\? ' }).Count
            $hl = git log -1 --format='%h %s' 2>$null
            [Console]::Write([char]27 + ']9001;tabgt-git;branch;'      + $b                          + [char]7)
            [Console]::Write([char]27 + ']9001;tabgt-git;status;'      + $st + ':' + $mo + ':' + $u + [char]7)
            [Console]::Write([char]27 + ']9001;tabgt-git;ahead-behind;' + $ahead + ':' + $behind     + [char]7)
            if ($hl) {
                $hi = $hl.IndexOf(' '); $h = $hl.Substring(0,$hi); $m = $hl.Substring($hi+1)
                [Console]::Write([char]27 + ']9001;tabgt-git;commit;' + $h + ':' + $m + [char]7)
            }
        }
        __tabgt_git
        $global:__tabgt_orig_prompt = ${function:prompt}
        function global:prompt {
            $r = if ($global:__tabgt_orig_prompt) { & $global:__tabgt_orig_prompt } else { "PS $($executionContext.SessionState.Path.CurrentLocation)> " }
            __tabgt_git
            $r
        }
        """
    }

    private static func encodeForPowerShell(_ script: String) -> String {
        guard let data = script.data(using: .utf16LittleEndian) else { return "" }
        return data.base64EncodedString()
    }

    static func applyLocalShellEnvironment(_ environment: inout [String: String], shellPath: String) {
        let name = URL(fileURLWithPath: shellPath).lastPathComponent.lowercased()

        let hook = "\(unixOscFunction); \(unixGitFunction); __tabgt_osc7; __tabgt_git"

        if name.contains("bash") {
            if let existing = environment["PROMPT_COMMAND"], !existing.isEmpty {
                environment["PROMPT_COMMAND"] = "\(hook); \(existing)"
            } else {
                environment["PROMPT_COMMAND"] = hook
            }
        } else if name.contains("zsh") {
            let home = environment["HOME"] ?? NSHomeDirectory()
            installZshIntegrationWrapper(home: home, hook: hook, environment: &environment)
        }
    }

    /// Replaces `ZDOTDIR` with wrapper startup files that source the user's real zsh config in order.
    /// Login shells read `.zprofile` before `.zshrc`; skipping `.zprofile` breaks Homebrew PATH on macOS.
    private static func installZshIntegrationWrapper(
        home: String,
        hook: String,
        environment: inout [String: String]
    ) {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("tabgt-zsh-\(UUID().uuidString)")

        let zprofile = """
        [ -f "\(home)/.zprofile" ] && ZDOTDIR="" source "\(home)/.zprofile"
        """

        let zshrc = """
        [ -f "\(home)/.zshrc" ] && ZDOTDIR="" source "\(home)/.zshrc"
        \(hook)
        precmd_functions+=(__tabgt_git)
        """

        let zlogin = """
        [ -f "\(home)/.zlogin" ] && ZDOTDIR="" source "\(home)/.zlogin"
        """

        do {
            try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
            try zprofile.write(to: tmpDir.appendingPathComponent(".zprofile"), atomically: true, encoding: .utf8)
            try zshrc.write(to: tmpDir.appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8)
            try zlogin.write(to: tmpDir.appendingPathComponent(".zlogin"), atomically: true, encoding: .utf8)
            environment["ZDOTDIR"] = tmpDir.path
        } catch {
            // Skip zsh integration hooks if temp startup files cannot be written.
        }
    }
}
