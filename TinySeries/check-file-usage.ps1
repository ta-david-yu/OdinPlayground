# Get the first command-line argument
$FileOrFolderPath = $args[0]

# Check if an argument was provided
if (-not $FileOrFolderPath) {
    Write-Warning "Please provide a file or folder path as the first argument."
    exit
}

# Check if the file or folder exists
if (-not (Test-Path -Path $FileOrFolderPath)) {
    Write-Warning "File or directory does not exist."
} else {
    # Check which process has the file open
    $LockingProcess = CMD /C "openfiles /query /fo table | find /I `"$FileOrFolderPath`""
    Write-Host $LockingProcess
}