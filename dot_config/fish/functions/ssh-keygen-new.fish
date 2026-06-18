function ssh-keygen-new
    set -l copy_key 1
    set -l add_agent 1
    set -l comment ""
    set -l name ""

    # Parse arguments (options can appear before or after NAME)
    while test (count $argv) -gt 0
        switch "$argv[1]"
            case -h --help
                printf '%s\n' \
                    'Usage:' \
                    '  ssh-keygen-new NAME [OPTIONS]' \
                    '' \
                    'Arguments:' \
                    '  NAME                Key filename (~/.ssh/NAME)' \
                    '' \
                    'Options:' \
                    '  -c, --comment TEXT  Key comment (defaults to NAME)' \
                    '      --no-copy       Do not copy public key to clipboard' \
                    '      --no-agent      Do not add key to SSH agent' \
                    '  -h, --help          Show this help'
                return 0

            case --comment -c
                if test (count $argv) -lt 2
                    printf 'Option %s requires an argument.\n' "$argv[1]" > /dev/stderr
                    return 1
                end
                if test -z "$argv[2]"
                    printf 'Option %s requires an argument.\n' "$argv[1]" > /dev/stderr
                    return 1
                end
                set comment "$argv[2]"
                set -e argv[1..2]

            case --no-copy
                set copy_key 0
                set -e argv[1]

            case --no-agent
                set add_agent 0
                set -e argv[1]

            case '*'
                # Reject stray/unknown flags
                if string match -q -- '-*' "$argv[1]"
                    printf 'Unknown option: %s\n' "$argv[1]" > /dev/stderr
                    return 1
                end
                if test -n "$name"
                    printf 'Unexpected argument: %s\n' "$argv[1]" > /dev/stderr
                    return 1
                end
                set name "$argv[1]"
                set -e argv[1]
        end
    end

    if test -z "$name"
        printf '%s\n' \
            'Error: NAME is required.' \
            '' \
            'Usage:' \
            '  ssh-keygen-new NAME [OPTIONS]' \
            '' \
            'Arguments:' \
            '  NAME                Key filename (~/.ssh/NAME)' \
            '' \
            'Options:' \
            '  -c, --comment TEXT  Key comment (defaults to NAME)' \
            '      --no-copy       Do not copy public key to clipboard' \
            '      --no-agent      Do not add key to SSH agent' \
            '  -h, --help          Show this help' > /dev/stderr
        return 1
    end

    if test -z "$comment"
        set comment "$name"
    end

    set key_path "$HOME/.ssh/$name"
    set pubkey "$key_path.pub"

    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    ssh-keygen -t ed25519 -C "$comment" -f "$key_path"
    or return

    if test "$copy_key" = 1
        if command -v wl-copy > /dev/null 2>/dev/null
            wl-copy < "$pubkey"
            echo "✓ Public key copied to clipboard."
        else if command -v xclip > /dev/null 2>/dev/null
            xclip -selection clipboard < "$pubkey"
            echo "✓ Public key copied to clipboard."
        else if command -v pbcopy > /dev/null 2>/dev/null
            pbcopy < "$pubkey"
            echo "✓ Public key copied to clipboard."
        else
            echo "Warning: no clipboard utility found." > /dev/stderr
        end
    end

    if test "$add_agent" = 1
        if ssh-add "$key_path" > /dev/null 2>/dev/null
            echo "✓ Key added to SSH agent."
        else
            echo "Warning: failed to add key to SSH agent." > /dev/stderr
        end
    end
end
