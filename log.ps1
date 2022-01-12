$filePath = $MyInvocation.MyCommand.Path;
$fileFolder = Split-Path -Path $filePath;
#fetch current path to run from any directory, and set it's location
Set-Location $fileFolder;
$excludes = @('Sc*' , 't*')
$apps = Get-ChildItem ../../ -Exclude $excludes;
# script folder to move archive files
$currentPath = chdir -Path .. -PassThru;
$scriptFolder = $currentPath.Path;

foreach( $app in $apps) {
    # read apps
    $appPath = $app.FullName;
    $envs = Get-ChildItem($appPath);
    $old_files = @();
    # read environments
    foreach($env in $envs) {
        $envPath = $env.FullName;
        $appDir = Get-ChildItem($envPath);
        # read inner apps
        foreach($innerApp in $appDir) {
            # check app with inner app
            if($app.Name -eq $innerApp.Name) {
                $config_files = Get-ChildItem($innerApp.FullName) -recurse -Include *config;
                foreach($config_file in $config_files) {
                    $fileContent = Get-Content ($config_file.FullName);
                    # read line by line

                    $dirNames = ""; $rentention = @();
                    foreach($line in $fileContent) {
                        # check dir name
                        if($line -match '(?<dir>.+)_RententionDays=(?<days>.+)') {
                            #by default , matched value pushing into matches array
                            $rentention += $matches;
                        }

                        if ($line -match '^dir=(?<path>.+)') {
                            #by default , matched value pushing into matches array
                            $dirNames = $matches.path;
                        }                 
                    }
                    
                    if($dirNames -ne "") {
                        $dirArray = $dirNames.Split(",");
                        # split all directories
                        foreach($dir in $dirArray) {
                            Try {
                                $isValidPath = Test-Path ($innerApp.FullName + '\' + $dir) -ErrorAction SilentlyContinue;
                                # check directory path is valid or not

                                if($isValidPath) {
                                    $appDetails = $rentention | Where-Object {$_.dir -eq $dir};
                                    $containerPath = $innerApp.FullName + '\' + $dir;
                                    $rententionDays = $appDetails.days;
                                    $old_files += Get-ChildItem $containerPath -Recurse -Force -ea 0 |? {!$_.PsIsContainer -and $_.LastWriteTime -lt (Get-Date).AddDays(-$rententionDays)};
                                }
                            }
                            Finally {
                                #"Invalid file path";
                             }
                        }
                    }
                }
            }
        }
    }

    if($old_files.length -gt 0) {
        $zipFileName = -join('Archive-',$app.Name,"-","$((Get-Date).ToString('dd-mmm-yyyy-HH-mm-ss'))")
        $archiveDir = "$appPath\$zipFileName";

        $file = @();
        foreach($old_file in $old_files) {
            $file+=$old_file.FullName;
        }

        $compress = @{
            LiteralPath= $file
            CompressionLevel = "Fastest"
            DestinationPath = $archiveDir
        }
        Compress-Archive @compress;        
        if($?){
            #check previous command executed or not, and delete files
            foreach($old_file in $old_files) {
                Remove-Item -Path $old_file.FullName -Force -Recurse
            }
            
            $zipFile = $archiveDir+'.zip';
            if(Test-Path $zipFile) {
                #check destination Archive exists then move to script output folder
                $outputFolder = $scriptFolder+'/output';
                Move-Item -Path $zipFile -Destination $outputFolder;
            } 
        } else {
            "Error in file compress";
        }
    }
}
