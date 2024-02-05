if ($args.length -lt 1) {
	write-output "provide filename"
	return
}

get-content -path $args[0] -asbytestream | set-variable bytes

$newBytes = @()

for ($i = 1; $i -lt $bytes.length; $i += 2) {
	$newBytes += $bytes[$i]
}

$filename = $args[0] + ".half"

$newBytes | set-content -path $filename -asbytestream
