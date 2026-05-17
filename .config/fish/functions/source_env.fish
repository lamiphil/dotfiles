function source_env --description "Source a .env file, exporting KEY=VALUE pairs"
    if not test -f $argv[1]
        return 0
    end
    for line in (grep -v '^#' $argv[1] | grep -v '^$' | grep '=')
        # Strip leading 'export ' if present
        set line (string replace 'export ' '' $line)
        # Split on first '=' only
        set parts (string split -m 1 '=' $line)
        if test (count $parts) -eq 2
            set key (string trim $parts[1])
            set val (string trim $parts[2])
            # Strip surrounding quotes (double or single)
            set val (string trim --chars='"' $val)
            set val (string trim --chars="'" $val)
            set -gx $key $val
        end
    end
end
