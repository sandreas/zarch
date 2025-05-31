<?php


$paths = [];
$currentPath = [];

$fp = fopen("path.txt", "rb");
while(!feof($fp)) {
    $line = fgets($fp);
    $trim = trim($line);
    if($trim == "") {
        if(count($currentPath) > 0) {
            $paths[] = $currentPath;
            $currentPath = [];
        }
        continue;
    }
    $currentPath[] = $trim;
}

function reverseSquare($path)
{

    $reversed = [
        $path[0],
        $path[2],
        $path[1],
        str_replace("v ", "v -", $path[2]),
        $path[3],
        $path[4],
    ];

    return $reversed;
}

foreach($paths as $key => $path) {
    if(count($path) == 5) {
        $paths[$key] = reverseSquare($path);
    }

    file_put_contents("path_output.txt", implode(PHP_EOL,$path).PHP_EOL.PHP_EOL, FILE_APPEND);
}

fclose($fp);