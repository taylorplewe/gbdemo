if ($args.length -lt 2) {
	write-output "provide filename and size"
	return
}

$filename = ""
$filename += {get-location}
$filename += $args[0]
$f = new-object System.IO.FileStream $filename, Open, ReadWrite

$f.SetLength($args[1])

$f.Close()
