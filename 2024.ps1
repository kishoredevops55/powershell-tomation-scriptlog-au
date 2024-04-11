$apps = Get-ChildItem ../../ -Directory

foreach ($app in $apps) {
    $envs = Get-ChildItem $app.FullName -Directory

    foreach ($env in $envs) {
        $innerApps = Get-ChildItem $env.FullName -Directory

        foreach ($innerApp in $innerApps) {
            $configFiles = Get-ChildItem $innerApp.FullName -Filter *config -File

            foreach ($configFile in $configFiles) {
                $configContent = Get-Content $configFile.FullName

                foreach ($line in $configContent) {
                    if ($line -match '^dir=(?<path>.+)') {
                        $dirNames = $matches['path'].Split(',')
                    }

                    if ($line -match '(?<dir>.+)_RententionDays=(?<days>.+)') {
                        $retentionDays = $matches['days']
                    }
                }

                if ($dirNames -and $retentionDays) {
                    foreach ($dir in $dirNames) {
                        $containerPath = Join-Path $innerApp.FullName $dir

                        if (Test-Path $containerPath -PathType Container) {
                            $oldFiles = Get-ChildItem $containerPath -File -Recurse |
                                        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$retentionDays) }

                            if ($oldFiles) {
                                $zipFileName = "Archive-$($app.Name)-$((Get-Date).ToString('dd-MMM-yyyy-HH-mm-ss')).zip"
                                $zipFilePath = Join-Path $env.FullName $zipFileName
                                Compress-Archive -Path $oldFiles.FullName -DestinationPath $zipFilePath -Force
                                $oldFiles | Remove-Item -Force
                                Move-Item -Path $zipFilePath -Destination "$PSScriptRoot\output" -Force
                            }
                        }
                    }
                }
            }
        }
    }
}
