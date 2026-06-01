import Foundation

/// Installs Claude Code hooks on a remote SSH host so TabGT can receive
/// live session events (tool use, file modifications, etc.) via OSC sequences.
actor ClaudeHookInstaller {
    enum Platform { case unix, windows }

    enum InstallError: LocalizedError {
        case invalidHost
        case sshCommandFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidHost:
                return "Cannot resolve SSH destination for this host."
            case .sshCommandFailed(let msg):
                return "SSH command failed: \(msg)"
            }
        }
    }

    static let shared = ClaudeHookInstaller()

    private init() {}

    // MARK: - Public API

    func install(on host: SSHHost) async throws {
        switch await probePlatform(host: host) {
        case .unix:  try await installUnix(on: host)
        case .windows: try await installWindows(on: host)
        }
    }

    func uninstall(from host: SSHHost) async throws {
        switch await probePlatform(host: host) {
        case .unix:  try await uninstallUnix(from: host)
        case .windows: try await uninstallWindows(from: host)
        }
    }

    /// Cleans up any broken hook entries (wrong paths, wrong JSON level) and reinstalls correctly.
    func repairHooks(on host: SSHHost) async throws {
        try await uninstall(from: host)
        try await install(on: host)
    }

    func isInstalled(on host: SSHHost) async -> Bool {
        // Works on bash (Linux/macOS/Git Bash) and PowerShell alike via the probe result
        let platform = await probePlatform(host: host)
        let checkCommand: String
        switch platform {
        case .unix:
            checkCommand = "test -f ~/.tabgt/claude-hook.sh && echo yes || echo no"
        case .windows:
            checkCommand = "powershell -NonInteractive -Command \"if (Test-Path '~\\.tabgt\\claude-hook.ps1') { 'yes' } else { 'no' }\""
        }
        guard let output = try? await runSSHCommand(host: host, command: checkCommand) else {
            return false
        }
        return output.trimmingCharacters(in: .whitespacesAndNewlines) == "yes"
    }

    // MARK: - Platform detection

    /// Detects whether bash is available on the remote for hook execution.
    /// This is independent of the SSH session shell (remoteShell) — Claude Code
    /// on Windows often uses bash (Git for Windows) regardless of the interactive shell.
    func probePlatform(host: SSHHost) async -> Platform {
        // Ask bash directly. If it's reachable and works, use Unix-style hooks.
        // Non-zero exit (bash not found) → try? returns nil → use Windows hooks.
        let output = try? await runSSHCommand(host: host, command: #"bash -c "echo BASH_OK""#)
        return output?.trimmingCharacters(in: .whitespacesAndNewlines) == "BASH_OK" ? .unix : .windows
    }

    func detectPlatform(host: SSHHost) -> Platform {
        guard let shell = host.remoteShell?.lowercased() else { return .unix }
        return SSHInputValidator.isWindowsRemoteShell(shell) ? .windows : .unix
    }

    // MARK: - Unix install

    private func installUnix(on host: SSHHost) async throws {
        let hookScriptB64 = Data(unixHookScript.utf8).base64EncodedString()
        let setupScript = unixSetupScript(hookScriptB64: hookScriptB64)
        let setupB64 = Data(setupScript.utf8).base64EncodedString()
        let command = "python3 -c \"import base64; exec(base64.b64decode('\(setupB64)').decode())\" || python3.exe -c \"import base64; exec(base64.b64decode('\(setupB64)').decode())\""
        _ = try await runSSHCommand(host: host, command: command)
    }

    private func uninstallUnix(from host: SSHHost) async throws {
        let removeScript = unixRemoveScript
        let removeB64 = Data(removeScript.utf8).base64EncodedString()
        let command = "python3 -c \"import base64; exec(base64.b64decode('\(removeB64)').decode())\""
        _ = try await runSSHCommand(host: host, command: command)
    }

    // MARK: - Windows install

    private func installWindows(on host: SSHHost) async throws {
        let hookScriptB64 = Data(windowsHookScript.utf8).base64EncodedString()
        let setupScript = windowsSetupScript(hookScriptB64: hookScriptB64)
        let encoded = encodeForPowerShell(setupScript)
        let command = "powershell -NonInteractive -EncodedCommand \(encoded)"
        _ = try await runSSHCommand(host: host, command: command)
    }

    private func uninstallWindows(from host: SSHHost) async throws {
        let encoded = encodeForPowerShell(windowsRemoveScript)
        let command = "powershell -NonInteractive -EncodedCommand \(encoded)"
        _ = try await runSSHCommand(host: host, command: command)
    }

    // MARK: - SSH execution

    @discardableResult
    private func runSSHCommand(host: SSHHost, command: String) async throws -> String {
        // SSHConfigBuilder uses @MainActor properties; capture them on the main actor first.
        let (args, extraEnv, sshPath) = await MainActor.run {
            let config = SSHConfigBuilder.execConfig(for: host, remoteCommand: command)
            return (config?.args, config?.extraEnvironment ?? [:], SSHConfigBuilder.sshPath)
        }
        guard let args else { throw InstallError.invalidHost }

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: sshPath)
            process.arguments = args

            var env = ProcessInfo.processInfo.environment
            for (key, value) in extraEnv { env[key] = value }
            process.environment = env

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            process.terminationHandler = { proc in
                let out = String(
                    data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(),
                    encoding: .utf8
                ) ?? ""
                if proc.terminationStatus != 0 {
                    let err = String(
                        data: stderrPipe.fileHandleForReading.readDataToEndOfFile(),
                        encoding: .utf8
                    ) ?? "SSH command failed"
                    continuation.resume(throwing: InstallError.sshCommandFailed(err.trimmingCharacters(in: .whitespacesAndNewlines)))
                } else {
                    continuation.resume(returning: out)
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - PowerShell encoding

    private func encodeForPowerShell(_ script: String) -> String {
        guard let data = script.data(using: .utf16LittleEndian) else { return "" }
        return data.base64EncodedString()
    }

    // MARK: - Remote scripts

    private var unixHookScript: String {
        """
        #!/bin/bash
        EVENT="$1"
        JSON=$(cat)
        osc() { printf "\\033]9001;tabgt-claude;%s;%s\\007" "$1" "$2" > /dev/tty; }
        py() { python3 -c "$1" 2>/dev/null; }

        case "$EVENT" in
          PreToolUse)
            TOOL=$(echo "$JSON" | py "import json,sys; print(json.load(sys.stdin).get('tool_name',''))")
            CWD=$(echo "$JSON"  | py "import json,sys; print(json.load(sys.stdin).get('cwd',''))")
            osc "active" ""
            osc "tool-start" "$TOOL"
            osc "cwd" "$CWD"
            ;;
          PostToolUse)
            TOOL=$(echo "$JSON" | py "import json,sys; print(json.load(sys.stdin).get('tool_name',''))")
            FILE=$(echo "$JSON" | py "import json,sys; d=json.load(sys.stdin); i=d.get('tool_input',{}); print(i.get('path','') or i.get('file_path',''))")
            [ -n "$FILE" ] && osc "file-modified" "$FILE"
            osc "tool-end" "$TOOL"
            ;;
          Notification) osc "active" "" ;;
          Stop)
            COST=$(echo "$JSON" | py "import json,sys; print(json.load(sys.stdin).get('total_cost',''))")
            osc "stop" "$COST"
            ;;
        esac
        exit 0
        """
    }

    private func unixSetupScript(hookScriptB64: String) -> String {
        // Use 'bash ~/.tabgt/claude-hook.sh' (with explicit bash prefix) as the command in
        // settings.json. This ensures the .sh script executes correctly even when Claude Code
        // runs hooks from a non-bash shell context (e.g. PowerShell on Windows with Git Bash).
        // Bash expands ~ correctly at runtime on both Linux and Git Bash on Windows.
        """
        import base64, json, os, stat
        tabgt = os.path.expanduser('~/.tabgt')
        os.makedirs(tabgt, exist_ok=True)
        hook = base64.b64decode('\(hookScriptB64)').decode('utf-8')
        hook_path = os.path.join(tabgt, 'claude-hook.sh')
        open(hook_path, 'w').write(hook)
        os.chmod(hook_path, 0o755)
        sp = os.path.expanduser('~/.claude/settings.json')
        claude_dir = os.path.dirname(sp)
        os.makedirs(claude_dir, exist_ok=True)
        s = json.load(open(sp)) if os.path.exists(sp) else {}
        h = s.setdefault('hooks', {})
        for e in ['PreToolUse', 'PostToolUse', 'Notification', 'Stop']:
            ents = h.setdefault(e, [])
            cmd = 'bash ~/.tabgt/claude-hook.sh ' + e
            if not any(hk.get('command') == cmd for en in ents for hk in en.get('hooks', [])):
                ents.append({'matcher': '', 'hooks': [{'type': 'command', 'command': cmd}]})
        json.dump(s, open(sp, 'w'), indent=2)
        print('OK')
        """
    }

    private var unixRemoveScript: String {
        // Also removes root-level stray entries left by the buggy Windows installer.
        """
        import json, os
        sp = os.path.expanduser('~/.claude/settings.json')
        if not os.path.exists(sp):
            print('OK'); exit()
        s = json.load(open(sp))
        def is_tabgt(cmd): return '.tabgt' in cmd and 'claude-hook' in cmd
        for e in ['PreToolUse', 'PostToolUse', 'Notification', 'Stop']:
            s.pop(e, None)
        h = s.get('hooks', {})
        for e in list(h.keys()):
            h[e] = [en for en in h[e] if not any(
                is_tabgt(hk.get('command', ''))
                for hk in en.get('hooks', [])
            )]
            if not h[e]:
                del h[e]
        if not h:
            s.pop('hooks', None)
        json.dump(s, open(sp, 'w'), indent=2)
        print('OK')
        """
    }

    private var windowsHookScript: String {
        // Uses PowerShell 5.1-compatible syntax (no ?? operator, no ternary).
        // [Console]::Write sends to stdout which flows through the SSH stream to TabGT,
        // and works correctly in both interactive and -NonInteractive subprocess mode.
        """
        param([string]$Event)
        $JSON = $input | Out-String
        function Send-OSC([string]$Type, [string]$Data = '') {
            [Console]::Write([char]27 + ']9001;tabgt-claude;' + $Type + ';' + $Data + [char]7)
        }
        function Coalesce($a, $b) { if ($null -ne $a -and $a -ne '') { $a } else { $b } }
        $p = $JSON | ConvertFrom-Json -ErrorAction SilentlyContinue
        switch ($Event) {
            'PreToolUse' {
                Send-OSC 'active'
                Send-OSC 'tool-start' (Coalesce $p.tool_name '')
                Send-OSC 'cwd' (Coalesce $p.cwd '')
            }
            'PostToolUse' {
                $file = Coalesce $p.tool_input.path (Coalesce $p.tool_input.file_path '')
                if ($file) { Send-OSC 'file-modified' $file }
                Send-OSC 'tool-end' (Coalesce $p.tool_name '')
            }
            'Notification' { Send-OSC 'active' }
            'Stop' { Send-OSC 'stop' (Coalesce $p.total_cost '') }
        }
        exit 0
        """
    }

    private func windowsSetupScript(hookScriptB64: String) -> String {
        """
        $tabgt = "$env:USERPROFILE\\.tabgt"
        New-Item -Force -ItemType Directory $tabgt | Out-Null
        $hookContent = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('\(hookScriptB64)'))
        Set-Content -Path "$tabgt\\claude-hook.ps1" -Value $hookContent
        $sp = "$env:USERPROFILE\\.claude\\settings.json"
        $spDir = Split-Path $sp
        if (-not (Test-Path $spDir)) { New-Item -ItemType Directory -Force $spDir | Out-Null }
        $s = if (Test-Path $sp) { Get-Content $sp -Raw | ConvertFrom-Json } else { [PSCustomObject]@{} }
        if (-not ($s.PSObject.Properties.Name -contains 'hooks')) {
            Add-Member -InputObject $s -NotePropertyName 'hooks' -NotePropertyValue ([PSCustomObject]@{})
        }
        $h = $s.hooks
        foreach ($evt in @('PreToolUse','PostToolUse','Notification','Stop')) {
            if (-not ($h.PSObject.Properties.Name -contains $evt)) {
                Add-Member -InputObject $h -NotePropertyName $evt -NotePropertyValue @()
            }
            $cmd = "powershell -NonInteractive -File `\"$tabgt\\claude-hook.ps1`\" $evt"
            $exists = $h.$evt | Where-Object { $_.hooks | Where-Object { $_.command -eq $cmd } }
            if (-not $exists) {
                $entry = [PSCustomObject]@{ matcher=''; hooks=@([PSCustomObject]@{type='command';command=$cmd}) }
                $h.$evt = @($h.$evt) + $entry
            }
        }
        $s | ConvertTo-Json -Depth 10 | Set-Content $sp
        Write-Output 'OK'
        """
    }

    private var windowsRemoveScript: String {
        """
        $sp = "$env:USERPROFILE\\.claude\\settings.json"
        if (-not (Test-Path $sp)) { Write-Output 'OK'; exit }
        $s = Get-Content $sp -Raw | ConvertFrom-Json
        foreach ($evt in @('PreToolUse','PostToolUse','Notification','Stop')) {
            $s.PSObject.Properties.Remove($evt)
        }
        if ($s.PSObject.Properties.Name -contains 'hooks') {
            $h = $s.hooks
            foreach ($evt in @('PreToolUse','PostToolUse','Notification','Stop')) {
                if ($h.PSObject.Properties.Name -contains $evt) {
                    $h.$evt = @($h.$evt | Where-Object {
                        -not ($_.hooks | Where-Object { $_.command -like '*.tabgt*claude-hook*' })
                    })
                }
            }
        }
        $s | ConvertTo-Json -Depth 10 | Set-Content $sp
        Write-Output 'OK'
        """
    }
}
