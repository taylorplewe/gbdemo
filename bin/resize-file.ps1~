if ($args.length -lt 2) {
	write-output "provide filename and length"
	return
}
 
$bytes = @()
get-content $args[0] -asbytestream | set-variable bytes
 
$newEnd = $args[1] - 1
$bytes = $bytes[0..$newEnd]
$bytes | set-content $args[0] -asbytestream
