$Array = @('A')
$Length=10
$LastArrChar = [byte][char]($Array[-1].ToUpper())
if ($LastArrChar -le 67 -or $LastArrChar -ge 90) {$LastArrChar = 67}
    While ($Array.Length -lt $Length) {
        $LastArrChar += 1        
        $Array += [char]$LastArrChar
    }


echo $Array