$XmlFolder = Join-Path $PSScriptRoot "documentation\xml"
$HtmlFolder = Join-Path $PSScriptRoot "docs"

if (-not (Test-Path $XmlFolder)) {
    Write-Host "Nie znaleziono folderu: $XmlFolder" -ForegroundColor Red
    exit
}

if (-not (Test-Path $HtmlFolder)) {
    New-Item -ItemType Directory -Path $HtmlFolder | Out-Null
}

function Encode-Html {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return "<em>Brak opisu.</em>"
    }

    $result = [System.Net.WebUtility]::HtmlEncode($Text)

    # Podstawowa obsługa znaczników dokumentacji Godota.
    $result = $result -replace '\[b\](.*?)\[/b\]', '<strong>$1</strong>'
    $result = $result -replace '\[i\](.*?)\[/i\]', '<em>$1</em>'
    $result = $result -replace '\[code\](.*?)\[/code\]', '<code>$1</code>'
    $result = $result -replace '\[br\]', '<br>'

    $result = $result -replace "`r`n", "<br>"
    $result = $result -replace "`n", "<br>"

    return $result
}

$Style = @"
<style>
body {
    font-family: Arial, Helvetica, sans-serif;
    max-width: 1100px;
    margin: 40px auto;
    padding: 0 25px;
    line-height: 1.6;
    color: #222;
}

h1 {
    border-bottom: 3px solid #333;
    padding-bottom: 10px;
}

h2 {
    margin-top: 35px;
    border-bottom: 1px solid #bbb;
    padding-bottom: 6px;
}

h3 {
    margin-top: 25px;
}

a {
    text-decoration: none;
}

a:hover {
    text-decoration: underline;
}

code {
    background: #eeeeee;
    padding: 2px 5px;
    border-radius: 4px;
}

.signature {
    background: #f3f3f3;
    border-left: 4px solid #555;
    padding: 10px;
    font-family: Consolas, monospace;
    margin-bottom: 10px;
}

.description {
    margin-bottom: 25px;
}

.meta {
    color: #666;
}

.class-list li {
    margin-bottom: 8px;
}
</style>
"@

$Classes = @()

$XmlFiles = Get-ChildItem -Path $XmlFolder -Filter "*.xml" |
    Sort-Object Name

foreach ($File in $XmlFiles) {

    try {
        $Xml = New-Object System.Xml.XmlDocument
        $Xml.PreserveWhitespace = $true
        $Xml.Load($File.FullName)
    }
    catch {
        Write-Host "Błąd XML: $($File.Name)" -ForegroundColor Red
        continue
    }

    $Class = $Xml.class

    if ($null -eq $Class) {
        Write-Host "Pominięto: $($File.Name)" -ForegroundColor Yellow
        continue
    }

    $ClassName = [string]$Class.name
    $Inherits = [string]$Class.inherits

    if ([string]::IsNullOrWhiteSpace($ClassName)) {
        $ClassName = $File.BaseName
    }

    $OutputFileName = $File.BaseName + ".html"
    $OutputPath = Join-Path $HtmlFolder $OutputFileName

    $Html = @"
<!DOCTYPE html>
<html lang="pl">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>$ClassName - dokumentacja</title>
$Style
</head>

<body>

<p><a href="index.html">← Powrót do strony głównej</a></p>

<h1>$ClassName</h1>
"@

    if (-not [string]::IsNullOrWhiteSpace($Inherits)) {
        $EncodedInherits = [System.Net.WebUtility]::HtmlEncode($Inherits)

        $Html += @"
<p class="meta">
Dziedziczy po: <code>$EncodedInherits</code>
</p>
"@
    }

    $Brief = [string]$Class.brief_description
    $Description = [string]$Class.description

    $Html += "<h2>Opis</h2>"

    if (-not [string]::IsNullOrWhiteSpace($Brief)) {
        $Html += "<p><strong>$(Encode-Html $Brief)</strong></p>"
    }

    $Html += "<p class='description'>$(Encode-Html $Description)</p>"

    # SYGNAŁY
    if ($null -ne $Class.signals.signal) {

        $Html += "<h2>Sygnały</h2>"

        foreach ($Signal in $Class.signals.signal) {

            $SignalName = [string]$Signal.name
            $Html += "<h3>$SignalName</h3>"

            $Parameters = @()

            foreach ($Param in $Signal.param) {
                $PName = [string]$Param.name
                $PType = [string]$Param.type

                if ([string]::IsNullOrWhiteSpace($PType)) {
                    $PType = "Variant"
                }

                $Parameters += "$PName`: $PType"
            }

            $Signature = "$SignalName(" + ($Parameters -join ", ") + ")"

            $Html += "<div class='signature'>$Signature</div>"

            $SignalDescription = [string]$Signal.description

            $Html += "<p class='description'>$(Encode-Html $SignalDescription)</p>"
        }
    }

    # ZMIENNE
    if ($null -ne $Class.members.member) {

        $Html += "<h2>Zmienne i właściwości</h2>"

        foreach ($Member in $Class.members.member) {

            $MemberName = [string]$Member.name
            $MemberType = [string]$Member.type
            $Default = [string]$Member.default

            if ([string]::IsNullOrWhiteSpace($MemberType)) {
                $MemberType = "Variant"
            }

            $Html += "<h3>$MemberName</h3>"

            $Signature = "$MemberName`: $MemberType"

            if (-not [string]::IsNullOrWhiteSpace($Default)) {
                $Signature += " = $Default"
            }

            $Html += "<div class='signature'>$Signature</div>"

            $MemberDescription = [string]$Member.InnerText

            $Html += "<p class='description'>$(Encode-Html $MemberDescription)</p>"
        }
    }

    # STAŁE I ENUMY
    if ($null -ne $Class.constants.constant) {

        $Html += "<h2>Stałe i wartości enum</h2>"

        foreach ($Constant in $Class.constants.constant) {

            $ConstantName = [string]$Constant.name
            $ConstantValue = [string]$Constant.value
            $EnumName = [string]$Constant.enum

            $Html += "<h3>$ConstantName</h3>"

            if (-not [string]::IsNullOrWhiteSpace($EnumName)) {
                $Html += "<p class='meta'>Enum: <code>$EnumName</code></p>"
            }

            $Html += "<div class='signature'>$ConstantName = $ConstantValue</div>"

            $ConstantDescription = [string]$Constant.InnerText

            $Html += "<p class='description'>$(Encode-Html $ConstantDescription)</p>"
        }
    }

    # METODY
    if ($null -ne $Class.methods.method) {

        $Html += "<h2>Metody</h2>"

        foreach ($Method in $Class.methods.method) {

            $MethodName = [string]$Method.name

            $Html += "<h3>$MethodName</h3>"

            $Parameters = @()

            foreach ($Param in $Method.param) {

                $PName = [string]$Param.name
                $PType = [string]$Param.type
                $PDefault = [string]$Param.default

                if ([string]::IsNullOrWhiteSpace($PType)) {
                    $PType = "Variant"
                }

                $ParameterText = "$PName`: $PType"

                if (-not [string]::IsNullOrWhiteSpace($PDefault)) {
                    $ParameterText += " = $PDefault"
                }

                $Parameters += $ParameterText
            }

            $ReturnType = "void"

            if ($null -ne $Method.return) {
                $TempReturn = [string]$Method.return.type

                if (-not [string]::IsNullOrWhiteSpace($TempReturn)) {
                    $ReturnType = $TempReturn
                }
            }

            $Signature =
                "$MethodName(" +
                ($Parameters -join ", ") +
                ") -> $ReturnType"

            $EncodedSignature =
                [System.Net.WebUtility]::HtmlEncode($Signature)

            $Html += "<div class='signature'>$EncodedSignature</div>"

            $MethodDescription = [string]$Method.description

            $Html += "<p class='description'>$(Encode-Html $MethodDescription)</p>"
        }
    }

    $Html += @"

</body>
</html>
"@

    $Utf8 = New-Object System.Text.UTF8Encoding($false)

    [System.IO.File]::WriteAllText(
        $OutputPath,
        $Html,
        $Utf8
    )

    $Classes += [PSCustomObject]@{
        Name = $ClassName
        File = $OutputFileName
        Inherits = $Inherits
    }

    Write-Host "Utworzono: $OutputFileName" -ForegroundColor Green
}

# INDEX.HTML
$IndexItems = ""

foreach ($Item in ($Classes | Sort-Object Name)) {

    $Name = [System.Net.WebUtility]::HtmlEncode($Item.Name)
    $FileName = [System.Net.WebUtility]::HtmlEncode($Item.File)

    $IndexItems += "<li><a href='$FileName'>$Name</a>"

    if (-not [string]::IsNullOrWhiteSpace($Item.Inherits)) {
        $Parent =
            [System.Net.WebUtility]::HtmlEncode($Item.Inherits)

        $IndexItems += " <span class='meta'>(extends $Parent)</span>"
    }

    $IndexItems += "</li>"
}

$Count = $Classes.Count

$IndexHtml = @"
<!DOCTYPE html>
<html lang="pl">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">

<title>Dokumentacja kodu projektu</title>

$Style
</head>

<body>

<h1>Dokumentacja kodu projektu</h1>

<p>
Dokumentacja została wygenerowana na podstawie dokumentacji XML
utworzonej przez Godot DocTool z komentarzy dokumentacyjnych
w kodzie GDScript.
</p>

<p>
Liczba udokumentowanych klas/skryptów:
<strong>$Count</strong>
</p>

<h2>Klasy i skrypty</h2>

<ul class="class-list">
$IndexItems
</ul>

</body>
</html>
"@

Set-Content `
    -Path (Join-Path $HtmlFolder "index.html") `
    -Value $IndexHtml `
    -Encoding UTF8

# Plik dla GitHub Pages
Set-Content `
    -Path (Join-Path $HtmlFolder ".nojekyll") `
    -Value "" `
    -Encoding UTF8

Write-Host ""
Write-Host "============================================"
Write-Host "Gotowe." -ForegroundColor Green
Write-Host "Dokumentacja HTML znajduje się w:"
Write-Host $HtmlFolder
Write-Host ""
Write-Host "Otwórz:"
Write-Host (Join-Path $HtmlFolder "index.html")
Write-Host "============================================"