#
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression.FileSystem

$form = New-Object Windows.Forms.Form
$form.Text = "Безопасное копирование с архивом и откатом"
$form.Size = New-Object Drawing.Size(640,450)
$form.StartPosition = "CenterScreen"

$btnSelectFolder = New-Object Windows.Forms.Button
$btnSelectFolder.Text = "Выбрать папку"
$btnSelectFolder.Size = New-Object Drawing.Size(120,30)
$btnSelectFolder.Location = New-Object Drawing.Point(20,20)

$label = New-Object Windows.Forms.Label
$label.Text = "Папка не выбрана"
$label.Location = New-Object Drawing.Point(160,25)
$label.Size = New-Object Drawing.Size(440,20)

$logBox = New-Object Windows.Forms.TextBox
$logBox.Multiline = $true
$logBox.ScrollBars = "Vertical"
$logBox.Location = New-Object Drawing.Point(20,60)
$logBox.Size = New-Object Drawing.Size(580,260)

$btnCopy = New-Object Windows.Forms.Button
$btnCopy.Text = "Копировать с архивом"
$btnCopy.Size = New-Object Drawing.Size(160,30)
$btnCopy.Location = New-Object Drawing.Point(20,330)

$btnDelete = New-Object Windows.Forms.Button
$btnDelete.Text = "Удалить пустые папки"
$btnDelete.Size = New-Object Drawing.Size(160,30)
$btnDelete.Location = New-Object Drawing.Point(200,330)

$btnRollback = New-Object Windows.Forms.Button
$btnRollback.Text = "Отменить копирование"
$btnRollback.Size = New-Object Drawing.Size(180,30)
$btnRollback.Location = New-Object Drawing.Point(380,330)

$selectedFolder = ""
$rollbackFile = "$env:TEMP\rollback.txt"
$backupPath = ""

$btnSelectFolder.Add_Click({
    $dialog = New-Object Windows.Forms.FolderBrowserDialog
    if ($dialog.ShowDialog() -eq "OK") {
        $selectedFolder = $dialog.SelectedPath
        $label.Text = "Выбрана папка: $selectedFolder"
    }
})

$btnCopy.Add_Click({
    if (-not $selectedFolder) {
        [System.Windows.Forms.MessageBox]::Show("Выберите папку.")
        return
    }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupPath = Join-Path $selectedFolder "Backup_$timestamp.zip"

    $logBox.AppendText("📦 Создание архива: $backupPath`r`n")
    [System.IO.Compression.ZipFile]::CreateFromDirectory($selectedFolder, $backupPath)

    $logBox.AppendText("🔄 Начинаем копирование файлов...`r`n")
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
        $logBox.AppendText("📁 Скопирован: $($file.FullName) → $destPath`r`n")
    }

    $logBox.AppendText("✅ Копирование завершено.`r`n")
})

$btnDelete.Add_Click({
    if (-not $selectedFolder) {
        [System.Windows.Forms.MessageBox]::Show("Сначала выберите папку.")
        return
    }

    $logBox.AppendText("🧹 Удаление пустых папок...`r`n")
    Get-ChildItem -Path $selectedFolder -Recurse -Directory |
        Sort-Object FullName -Descending |
        Where-Object { ($_.GetFileSystemInfos().Count -eq 0) } |
        ForEach-Object {
            Remove-Item $_.FullName -Force
            $logBox.AppendText("🗑️ Удалена: $($_.FullName)`r`n")
        }
    $logBox.AppendText("✅ Удаление завершено.`r`n")
})

$btnRollback.Add_Click({
    if (!(Test-Path $rollbackFile)) {
        [System.Windows.Forms.MessageBox]::Show("Нет информации для отката.")
        return
    }

    $logBox.AppendText("⏪ Откат: удаление скопированных файлов...`r`n")
    Get-Content $rollbackFile | ForEach-Object {
        if (Test-Path $_) {
            Remove-Item $_ -Force
            $logBox.AppendText("❌ Удалён: $_`r`n")
        }
    }

    if (Test-Path $backupPath) {
        $logBox.AppendText("📦 Восстановление из архива...`r`n")
        [System.IO.Compression.ZipFile]::ExtractToDirectory($backupPath, $selectedFolder, $true)
        $logBox.AppendText("✅ Восстановлено из $backupPath`r`n")
    } else {
        $logBox.AppendText("⚠️ Архив не найден. Восстановление невозможно.`r`n")
    }

    $logBox.AppendText("🔁 Откат завершён.`r`n")
})

$form.Controls.Add($btnSelectFolder)
$form.Controls.Add($label)
$form.Controls.Add($logBox)
$form.Controls.Add($btnCopy)
$form.Controls.Add($btnDelete)
$form.Controls.Add($btnRollback)

[void]$form.ShowDialog()
