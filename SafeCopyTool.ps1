#
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression.FileSystem

$form = New-Object Windows.Forms.Form
$form.Text = "Secure backup with archive and rollback"
$form.Size = New-Object Drawing.Size(640,450)
$form.StartPosition = "CenterScreen"

$btnSelectFolder = New-Object Windows.Forms.Button
$btnSelectFolder.Text = "Select a folder"
$btnSelectFolder.Size = New-Object Drawing.Size(120,30)
$btnSelectFolder.Location = New-Object Drawing.Point(20,20)

$label = New-Object Windows.Forms.Label
$label.Text = "Folder not selected"
$label.Location = New-Object Drawing.Point(160,25)
$label.Size = New-Object Drawing.Size(440,20)

$logBox = New-Object Windows.Forms.TextBox
$logBox.Multiline = $true
$logBox.ScrollBars = "Vertical"
$logBox.Location = New-Object Drawing.Point(20,60)
$logBox.Size = New-Object Drawing.Size(580,260)

$btnCopy = New-Object Windows.Forms.Button
$btnCopy.Text = "Copy with archive"
$btnCopy.Size = New-Object Drawing.Size(160,30)
$btnCopy.Location = New-Object Drawing.Point(20,330)

$btnDelete = New-Object Windows.Forms.Button
$btnDelete.Text = "Delete empty folders"
$btnDelete.Size = New-Object Drawing.Size(160,30)
$btnDelete.Location = New-Object Drawing.Point(200,330)

$btnRollback = New-Object Windows.Forms.Button
$btnRollback.Text = "Cancel copying"
$btnRollback.Size = New-Object Drawing.Size(180,30)
$btnRollback.Location = New-Object Drawing.Point(380,330)

$selectedFolder = ""
$rollbackFile = "$env:TEMP\rollback.txt"
$backupPath = ""

$btnSelectFolder.Add_Click({
    $dialog = New-Object Windows.Forms.FolderBrowserDialog
    if ($dialog.ShowDialog() -eq "OK") {
        $selectedFolder = $dialog.SelectedPath
        $label.Text = "Folder selected: $selectedFolder"
    }
})

$btnCopy.Add_Click({
    if (-not $selectedFolder) {
        [System.Windows.Forms.MessageBox]::Show("Select a folder.")
        return
    }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupPath = Join-Path $selectedFolder "Backup_$timestamp.zip"

    $logBox.AppendText("📦 Creating an archive: $backupPath`r`n")
    [System.IO.Compression.ZipFile]::CreateFromDirectory($selectedFolder, $backupPath)

    $logBox.AppendText("🔄 Starting copying files...`r`n")
    "" | Set-Content $rollbackFile

    $files = Get-ChildItem -Path $selectedFolder -Recurse -File
    foreach ($file in $files) {
        $destPath = Join-Path $selectedFolder $file.Name
        $base = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        $ext = $file.Extension
        $counter = 1

        while (Test-Path $destPath) {
            $destPath = Join-Path $selectedFolder "$base`_$counter$ext"
            $counter++
        }

        Copy-Item $file.FullName $destPath
        Add-Content $rollbackFile $destPath
        $logBox.AppendText("📁 Copied: $($file.FullName) → $destPath`r`n")
    }

    $logBox.AppendText("✅ Copying completed.`r`n")
})

$btnDelete.Add_Click({
    if (-not $selectedFolder) {
        [System.Windows.Forms.MessageBox]::Show("First, select the folder.")
        return
    }

    $logBox.AppendText("🧹 Deleting empty folders...`r`n")
    Get-ChildItem -Path $selectedFolder -Recurse -Directory |
        Sort-Object FullName -Descending |
        Where-Object { ($_.GetFileSystemInfos().Count -eq 0) } |
        ForEach-Object {
            Remove-Item $_.FullName -Force
            $logBox.AppendText("🗑️ Deleted: $($_.FullName)`r`n")
        }
    $logBox.AppendText("✅ Deletion completed.`r`n")
})

$btnRollback.Add_Click({
    if (!(Test-Path $rollbackFile)) {
        [System.Windows.Forms.MessageBox]::Show("There is no information to roll back.")
        return
    }

    $logBox.AppendText("⏪ Rollback: deleting copied files...`r`n")
    Get-Content $rollbackFile | ForEach-Object {
        if (Test-Path $_) {
            Remove-Item $_ -Force
            $logBox.AppendText("❌ Deleted: $_`r`n")
        }
    }

    if (Test-Path $backupPath) {
        $logBox.AppendText("📦 Restoring from the archive...`r`n")
        [System.IO.Compression.ZipFile]::ExtractToDirectory($backupPath, $selectedFolder, $true)
        $logBox.AppendText("✅ Retrieved from $backupPath`r`n")
    } else {
        $logBox.AppendText("⚠️ The archive was not found. Recovery is not possible.`r`n")
    }

    $logBox.AppendText("🔁 Rollback completed.`r`n")
})

$form.Controls.Add($btnSelectFolder)
$form.Controls.Add($label)
$form.Controls.Add($logBox)
$form.Controls.Add($btnCopy)
$form.Controls.Add($btnDelete)
$form.Controls.Add($btnRollback)

[void]$form.ShowDialog()
