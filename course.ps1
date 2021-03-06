$author = 'jim-christopher';
$courseid = 'application-instrumentation-perfcounters';
$clips = "./clips";
$course = "./${courseid}-m${moduleid}";
$demo = ".\demo";
$publishPoint = 'c:\users\beefarino\DropBox (Pluralsight)\jim-christopher'

assert ($moduleid -ne $null) "You must define the variable `$moduleid before including the course psake task file";
assert ($moduleTitle -ne $null) "You must define the variable `$moduleTitle before including the course psake task file";

task create-courseFolder -precondition{ test-path $course } {
    mkdir $course -force | out-null;
}

task publish-module {
    $dest = join-path $publishPoint $course
    mkdir $dest -force | out-null;
    cp $course -dest $publishPoint -Container -Force -Verbose -Recurse
}

task rename-clips {
    ls $clips | where {$_.name -notmatch "^$courseid-m$moduleid"} | rename-item -new { "$courseid-m$moduleid-$($_.name)" }
    ls $clips | where {$_.name -match "$courseid-m$moduleid-(\d)-"} | rename-item -new { $_.name -replace "$courseid-m$moduleid-(\d)-", "$courseid-m$moduleid-0`$1-" }
}

task verify -depends verify-metafile, verify-questions, verify-slides, verify-author

task verify-author -depends package {
    $meta = [xml](gc $course/*.meta);    
    
}

task verify-metafile -depends package {
    $asserts = @();

    $meta = [xml](gc $course/*.meta);    
    $clips = ls $course/*.wmv | select -exp name;
    $refs = $meta.module.clips.clip | select -exp href;
    $titles = $meta.module.clips.clip | select -exp title;

    # check author value
    $metaAuthor = $meta.module.author;
    if( $metaAuthor -ne $author ) 
    {
        $asserts += "Metdata author element value '$metaAuthor' does not equal course author value '$author'";
    }
    
    # check clip list to file list
    $diffs = compare-object $clips $refs | out-string
    if( $diffs ) 
    {
        $asserts += "Module metadata and clip catalog differ: $diffs";
    }

    # check title lengths
    $asserts += $titles | where {$_.length -ge 65} | foreach { "Clip title '$_' is greater than 65 characters" };
    
    # check for evil underscores
    $asserts += $clips | where {$_ -match '_'} | foreach { "Clip href '$_' contains an underscore" };

    assert (-not $asserts) ($asserts -join "`r`n") 
}


task generate-metafile -depends create-courseFolder,rename-clips {
    $meta = "${courseid}-m${moduleid}.meta";
    $clips = ls $clips/*.wmv | select -exp name | sort;
    
    $c = @"
    <clip href="{0}" title="" />
"@
    $t = @"
<?xml version="1.0"?>
<module xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="http://pluralsight.com/sapphire/module/2007/11">
  <author>$author</author>
  <title>$moduleTitle</title>
  <description>$moduleDescription</description>
  <clips>
{0}
  </clips>
</module>
"@
    $clipElements = $clips | foreach-object { $c -f $_ };
    $xml = $t -f ($clipElements -join [environment]::newLine);
    $xml | write-host;
    $xml | out-file $meta -Encoding utf8;
}

task verify-questions -depends package, verify-responseLengths {
    $txt = (gc $course/questions.txt) -match '^=\s+' -replace '^=\s+','';    
    $clips = ls $course/*.wmv | select -exp name;
        
    $a = @();
    $txt | %{ if(-not($clips -contains $_)){ $a += "Module questions and clip catalog differ: $_`r`n" } };
    assert (-not $a) $a;    
}

task verify-responseLengths -depends package {
    $txt = (gc $course/questions.txt) | where {$_ -match '^[-*]\s+'} | foreach {$_ -replace '^.\s+',''};    
            
    $a = @();
    $txt | %{ if($_.length -gt 100){ $a += "Question response exceeds 100 characters: $_`r`n" } };
    assert (-not $a) $a;    
}

task verify-slides -depends package {
    
    assert (test-path $course/slides.pptx) "no slides.pptx file can be found in module package";    
}

task package -depends create-courseFolder,rename-clips,package-demo {
    ri $course -force -recurse -erroraction 'silentlycontinue';
    mkdir $course -force | out-null;
    
    ls $clips | cp -dest $course
    cp ./*.meta,./questions.txt,./exercise-files.zip,slides.pptx -dest $course   
}

task package-demo {
    if( test-path exercise-files.zip )
    {
        remove-item exercise-files.zip
    }

    [Reflection.Assembly]::LoadWithPartialName( "System.IO.Compression.FileSystem" ) | out-null;
    $compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
    [System.IO.Compression.ZipFile]::CreateFromDirectory( (join-path $pwd $demo), "$pwd\exercise-files.zip", $compressionLevel, $false ) | out-null;
}

task init-module {
    mkdir $clips,$course,$demo,./project,./raw;
}