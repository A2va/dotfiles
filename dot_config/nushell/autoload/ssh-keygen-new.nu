use std/clip

export def ssh-keygen-new [
    name: string,
    --comment (-c): string,
    --no-copy,
    --no-agent,
] {
    let comment = if ($comment | is-empty) { $name } else { $comment }
    let ssh_dir = ($nu.home-dir | path join ".ssh")
    let key_path = ($ssh_dir | path join $name)
    let pubkey = $"($key_path).pub"

    if not ($ssh_dir | path exists) {
        mkdir $ssh_dir
    }

    # Generate the SSH Key
    ^ssh-keygen -t ed25519 -C $comment -f $key_path

    if $env.LAST_EXIT_CODE != 0 {
        return
    }

    # Copy to clipboard using standard library
    if not $no_copy {
        if ($pubkey | path exists) {
            open $pubkey | clip copy
            print "✓ Public key copied to clipboard via std/clip."
        } else {
            print --stderr "Error: Public key file not found."
        }
    }

    # Add to SSH Agent
    if not $no_agent {
        ^ssh-add $key_path o+e>| ignore

        if $env.LAST_EXIT_CODE == 0 {
            print "✓ Key added to SSH agent."
        } else {
            print --stderr "Warning: failed to add key to SSH agent."
        }
    }
}
