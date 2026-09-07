# ============================================================
# Godot 4 - XML documentation -> HTML
# Windows PowerShell 5.1 compatible
# ============================================================

$ProjectDir = $PSScriptRoot
$XmlDir = Join-Path $ProjectDir "documentation\xml"
$DocsDir = Join-Path $ProjectDir "docs"
$DocsXmlDir = Join-Path $DocsDir "xml"

$Utf8 = New-Object System.Text.UTF8Encoding($false)

# ------------------------------------------------------------
# Helper functions
# ------------------------------------------------------------

function SaveUtf8 {
    param(
        [string]$Path,
        [string]$Content
    )

    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        $Utf8
    )
}


function HtmlEncode {
    param(
        [AllowNull()]
        [string]$Text
    )

    if ($null -eq $Text) {
        return ""
    }

    return [System.Net.WebUtility]::HtmlEncode($Text)
}


function GetNodeText {
    param($Node)

    if ($null -eq $Node) {
        return ""
    }

    return [string]$Node.InnerText
}


function FormatDocText {
    param(
        [AllowNull()]
        [string]$Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return "<em>Brak opisu.</em>"
    }

    $Result = [System.Net.WebUtility]::HtmlEncode($Text)

    # Godot BBCode-like documentation tags
    $Result = $Result -replace '\[b\](.*?)\[/b\]', '<strong>$1</strong>'
    $Result = $Result -replace '\[i\](.*?)\[/i\]', '<em>$1</em>'
    $Result = $Result -replace '\[code\](.*?)\[/code\]', '<code>$1</code>'
    $Result = $Result -replace '\[kbd\](.*?)\[/kbd\]', '<code>$1</code>'

    $Result = $Result -replace '\[param ([^\]]+)\]', '<code>$1</code>'
    $Result = $Result -replace '\[method ([^\]]+)\]', '<code>$1</code>'
    $Result = $Result -replace '\[member ([^\]]+)\]', '<code>$1</code>'
    $Result = $Result -replace '\[signal ([^\]]+)\]', '<code>$1</code>'
    $Result = $Result -replace '\[constant ([^\]]+)\]', '<code>$1</code>'
    $Result = $Result -replace '\[enum ([^\]]+)\]', '<code>$1</code>'

    $Result = $Result -replace '\[br\]', '<br>'

    $Result = $Result.Replace("`r`n", "<br>")
    $Result = $Result.Replace("`n", "<br>")

    return $Result
}


function GetAttr {
    param(
        $Node,
        [string]$Name
    )

    if ($null -eq $Node) {
        return ""
    }

    return [string]$Node.GetAttribute($Name)
}


# ------------------------------------------------------------
# Input check
# ------------------------------------------------------------

if (-not (Test-Path $XmlDir)) {
    Write-Host "ERROR: XML folder not found:" -ForegroundColor Red
    Write-Host $XmlDir
    exit 1
}

$XmlFiles = @(
    Get-ChildItem `
        -Path $XmlDir `
        -Filter "*.xml" `
        -File |
    Sort-Object Name
)

if ($XmlFiles.Count -eq 0) {
    Write-Host "ERROR: No XML files found." -ForegroundColor Red
    exit 1
}


# ------------------------------------------------------------
# Recreate docs directory
# ------------------------------------------------------------

if (Test-Path $DocsDir) {
    Remove-Item `
        -Path $DocsDir `
        -Recurse `
        -Force
}

New-Item `
    -ItemType Directory `
    -Path $DocsDir |
Out-Null

New-Item `
    -ItemType Directory `
    -Path $DocsXmlDir |
Out-Null


# ------------------------------------------------------------
# CSS
# ------------------------------------------------------------

$Css = @"
<style>

* {
    box-sizing: border-box;
}

body {
    font-family: Arial, Helvetica, sans-serif;
    max-width: 1150px;
    margin: 0 auto;
    padding: 35px;
    line-height: 1.6;
    color: #222;
    background: #fff;
}

h1 {
    border-bottom: 3px solid #333;
    padding-bottom: 10px;
}

h2 {
    margin-top: 40px;
    border-bottom: 1px solid #bbb;
    padding-bottom: 6px;
}

h3 {
    margin-top: 26px;
    margin-bottom: 8px;
}

a {
    color: #1d5fa7;
    text-decoration: none;
}

a:hover {
    text-decoration: underline;
}

code {
    font-family: Consolas, "Courier New", monospace;
    background: #eee;
    padding: 2px 6px;
    border-radius: 4px;
}

.signature {
    font-family: Consolas, "Courier New", monospace;
    background: #f3f3f3;
    border-left: 4px solid #555;
    padding: 10px 14px;
    margin: 8px 0 12px 0;
    overflow-wrap: anywhere;
}

.description {
    margin-bottom: 25px;
}

.meta {
    color: #666;
}

.back {
    margin-bottom: 25px;
}

.class-list li {
    margin-bottom: 9px;
}

.info {
    background: #f3f6f9;
    border-left: 4px solid #4d718e;
    padding: 12px 15px;
    margin: 20px 0;
}

.xml-link {
    margin-top: 15px;
}

footer {
    margin-top: 60px;
    padding-top: 15px;
    border-top: 1px solid #ccc;
    color: #777;
    font-size: 0.9em;
}

</style>
"@


# ------------------------------------------------------------
# Start
# ------------------------------------------------------------

Write-Host ""
Write-Host "============================================"
Write-Host "Godot XML -> HTML"
Write-Host "============================================"
Write-Host "XML files found: $($XmlFiles.Count)"
Write-Host ""


$Classes = @()


foreach ($File in $XmlFiles) {

    Write-Host "Processing: $($File.Name)"

    # Copy original XML to GitHub Pages directory
    Copy-Item `
        -Path $File.FullName `
        -Destination $DocsXmlDir `
        -Force

    try {
        $Xml = New-Object System.Xml.XmlDocument
        $Xml.PreserveWhitespace = $false

        # Reads encoding from the XML declaration
        $Xml.Load($File.FullName)
    }
    catch {
        Write-Host "  ERROR: Cannot read XML." -ForegroundColor Red
        Write-Host "  $($_.Exception.Message)"
        continue
    }


    # --------------------------------------------------------
    # IMPORTANT:
    # Find <class> regardless of namespace or wrapper.
    # --------------------------------------------------------

    $Class = $Xml.SelectSingleNode(
        "//*[local-name()='class']"
    )

    if ($null -eq $Class) {

        Write-Host `
            "  ERROR: No <class> element found." `
            -ForegroundColor Red

        Write-Host `
            "  Root element: $($Xml.DocumentElement.Name)" `
            -ForegroundColor Yellow

        continue
    }


    # --------------------------------------------------------
    # Class information
    # --------------------------------------------------------

    $ClassName = GetAttr $Class "name"

    if ([string]::IsNullOrWhiteSpace($ClassName)) {
        $ClassName = $File.BaseName
    }

    $Inherits = GetAttr $Class "inherits"
    $Version = GetAttr $Class "version"

    $SafeClassName = HtmlEncode $ClassName
    $SafeInherits = HtmlEncode $Inherits
    $SafeVersion = HtmlEncode $Version

    $HtmlFileName = $File.BaseName + ".html"
    $HtmlPath = Join-Path $DocsDir $HtmlFileName

    $XmlLinkName =
        [System.Uri]::EscapeDataString($File.Name)


    # --------------------------------------------------------
    # Page header
    # --------------------------------------------------------

    $Html = @"
<!DOCTYPE html>
<html lang="pl">

<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">

<title>$SafeClassName - dokumentacja</title>

$Css
</head>

<body>

<div class="back">
<a href="index.html">
&larr; Powr&#243;t do listy klas
</a>
</div>

<h1>$SafeClassName</h1>
"@


    if (-not [string]::IsNullOrWhiteSpace($Inherits)) {
        $Html += @"
<p class="meta">
Dziedziczy po: <code>$SafeInherits</code>
</p>
"@
    }


    if (-not [string]::IsNullOrWhiteSpace($Version)) {
        $Html += @"
<p class="meta">
Wersja Godot: $SafeVersion
</p>
"@
    }


    $Html += @"
<p class="xml-link">
<a href="xml/$XmlLinkName">
Poka&#380; oryginalny XML wygenerowany przez Godot
</a>
</p>
"@


    # --------------------------------------------------------
    # Description
    # --------------------------------------------------------

    $BriefNode = $Class.SelectSingleNode(
        "./*[local-name()='brief_description']"
    )

    $DescriptionNode = $Class.SelectSingleNode(
        "./*[local-name()='description']"
    )

    $Brief = GetNodeText $BriefNode
    $Description = GetNodeText $DescriptionNode


    $Html += "<h2>Opis</h2>"


    if (-not [string]::IsNullOrWhiteSpace($Brief)) {
        $Html += @"
<p>
<strong>$(FormatDocText $Brief)</strong>
</p>
"@
    }


    $Html += @"
<div class="description">
$(FormatDocText $Description)
</div>
"@


    # --------------------------------------------------------
    # Signals
    # --------------------------------------------------------

    $Signals = @(
        $Class.SelectNodes(
            "./*[local-name()='signals']/*[local-name()='signal']"
        )
    )


    if ($Signals.Count -gt 0) {

        $Html += "<h2>Sygna&#322;y</h2>"

        foreach ($Signal in $Signals) {

            $SignalName = GetAttr $Signal "name"
            $SafeSignalName = HtmlEncode $SignalName

            $Parameters = @()

            $SignalParams = @(
                $Signal.SelectNodes(
                    "./*[local-name()='param']"
                )
            )

            foreach ($Param in $SignalParams) {

                $ParamName = GetAttr $Param "name"
                $ParamType = GetAttr $Param "type"

                if ([string]::IsNullOrWhiteSpace($ParamType)) {
                    $ParamType = "Variant"
                }

                $Parameters += "$ParamName`: $ParamType"
            }

            $Signature =
                $SignalName +
                "(" +
                ($Parameters -join ", ") +
                ")"

            $SafeSignature = HtmlEncode $Signature

            $SignalDescriptionNode =
                $Signal.SelectSingleNode(
                    "./*[local-name()='description']"
                )

            $SignalDescription =
                GetNodeText $SignalDescriptionNode


            $Html += @"
<h3>$SafeSignalName</h3>

<div class="signature">
$SafeSignature
</div>

<div class="description">
$(FormatDocText $SignalDescription)
</div>
"@
        }
    }


    # --------------------------------------------------------
    # Members / variables
    # --------------------------------------------------------

    $Members = @(
        $Class.SelectNodes(
            "./*[local-name()='members']/*[local-name()='member']"
        )
    )


    if ($Members.Count -gt 0) {

        $Html += `
            "<h2>Zmienne i w&#322;a&#347;ciwo&#347;ci</h2>"

        foreach ($Member in $Members) {

            $MemberName = GetAttr $Member "name"
            $MemberType = GetAttr $Member "type"
            $DefaultValue = GetAttr $Member "default"

            if ([string]::IsNullOrWhiteSpace($MemberType)) {
                $MemberType = "Variant"
            }

            $Signature =
                "$MemberName`: $MemberType"

            if (
                -not [string]::IsNullOrWhiteSpace(
                    $DefaultValue
                )
            ) {
                $Signature += " = $DefaultValue"
            }

            $SafeMemberName = HtmlEncode $MemberName
            $SafeSignature = HtmlEncode $Signature

            $MemberDescription =
                GetNodeText $Member


            $Html += @"
<h3>$SafeMemberName</h3>

<div class="signature">
$SafeSignature
</div>

<div class="description">
$(FormatDocText $MemberDescription)
</div>
"@
        }
    }


    # --------------------------------------------------------
    # Constants and enums
    # --------------------------------------------------------

    $Constants = @(
        $Class.SelectNodes(
            "./*[local-name()='constants']/*[local-name()='constant']"
        )
    )

    $NormalConstants = @()
    $EnumGroups = @{}


    foreach ($Constant in $Constants) {

        $EnumName = GetAttr $Constant "enum"

        if ([string]::IsNullOrWhiteSpace($EnumName)) {
            $NormalConstants += $Constant
        }
        else {

            if (-not $EnumGroups.ContainsKey($EnumName)) {
                $EnumGroups[$EnumName] = @()
            }

            $EnumGroups[$EnumName] += $Constant
        }
    }


    if ($NormalConstants.Count -gt 0) {

        $Html += "<h2>Sta&#322;e</h2>"

        foreach ($Constant in $NormalConstants) {

            $ConstantName = GetAttr $Constant "name"
            $ConstantValue = GetAttr $Constant "value"

            $Signature =
                "$ConstantName = $ConstantValue"

            $SafeConstantName =
                HtmlEncode $ConstantName

            $SafeSignature =
                HtmlEncode $Signature

            $ConstantDescription =
                GetNodeText $Constant


            $Html += @"
<h3>$SafeConstantName</h3>

<div class="signature">
$SafeSignature
</div>

<div class="description">
$(FormatDocText $ConstantDescription)
</div>
"@
        }
    }


    if ($EnumGroups.Count -gt 0) {

        $Html += "<h2>Typy wyliczeniowe (enum)</h2>"

        foreach (
            $EnumName in (
                $EnumGroups.Keys |
                Sort-Object
            )
        ) {

            $SafeEnumName =
                HtmlEncode $EnumName

            $Html += "<h3>$SafeEnumName</h3>"
            $Html += "<ul>"

            foreach (
                $Constant in $EnumGroups[$EnumName]
            ) {

                $ConstantName =
                    GetAttr $Constant "name"

                $ConstantValue =
                    GetAttr $Constant "value"

                $SafeConstantName =
                    HtmlEncode $ConstantName

                $SafeConstantValue =
                    HtmlEncode $ConstantValue

                $ConstantDescription =
                    GetNodeText $Constant


                $Html += @"
<li>
<code>$SafeConstantName = $SafeConstantValue</code>
"@


                if (
                    -not [string]::IsNullOrWhiteSpace(
                        $ConstantDescription
                    )
                ) {
                    $Html += `
                        " - $(FormatDocText $ConstantDescription)"
                }

                $Html += "</li>"
            }

            $Html += "</ul>"
        }
    }


    # --------------------------------------------------------
    # Methods
    # --------------------------------------------------------

    $Methods = @(
        $Class.SelectNodes(
            "./*[local-name()='methods']/*[local-name()='method']"
        )
    )


    if ($Methods.Count -gt 0) {

        $Html += "<h2>Metody</h2>"

        foreach ($Method in $Methods) {

            $MethodName =
                GetAttr $Method "name"

            $SafeMethodName =
                HtmlEncode $MethodName

            $Parameters = @()

            $MethodParams = @(
                $Method.SelectNodes(
                    "./*[local-name()='param']"
                )
            )


            $SortedParams = @(
                $MethodParams |
                Sort-Object {

                    $IndexText =
                        GetAttr $_ "index"

                    if (
                        [string]::IsNullOrWhiteSpace(
                            $IndexText
                        )
                    ) {
                        return 999
                    }

                    return [int]$IndexText
                }
            )


            foreach ($Param in $SortedParams) {

                $ParamName =
                    GetAttr $Param "name"

                $ParamType =
                    GetAttr $Param "type"

                $ParamDefault =
                    GetAttr $Param "default"

                if (
                    [string]::IsNullOrWhiteSpace(
                        $ParamType
                    )
                ) {
                    $ParamType = "Variant"
                }

                $ParameterText =
                    "$ParamName`: $ParamType"

                if (
                    -not [string]::IsNullOrWhiteSpace(
                        $ParamDefault
                    )
                ) {
                    $ParameterText += `
                        " = $ParamDefault"
                }

                $Parameters += $ParameterText
            }


            $ReturnType = "void"

            $ReturnNode =
                $Method.SelectSingleNode(
                    "./*[local-name()='return']"
                )

            if ($null -ne $ReturnNode) {

                $TempReturn =
                    GetAttr $ReturnNode "type"

                if (
                    -not [string]::IsNullOrWhiteSpace(
                        $TempReturn
                    )
                ) {
                    $ReturnType = $TempReturn
                }
            }


            $Signature =
                $MethodName +
                "(" +
                ($Parameters -join ", ") +
                ") -> " +
                $ReturnType

            $SafeSignature =
                HtmlEncode $Signature


            $MethodDescriptionNode =
                $Method.SelectSingleNode(
                    "./*[local-name()='description']"
                )

            $MethodDescription =
                GetNodeText $MethodDescriptionNode


            $Html += @"
<h3>$SafeMethodName</h3>

<div class="signature">
$SafeSignature
</div>

<div class="description">
$(FormatDocText $MethodDescription)
</div>
"@
        }
    }


    # --------------------------------------------------------
    # Footer
    # --------------------------------------------------------

    $Html += @"
<footer>
Dokumentacja wygenerowana na podstawie XML utworzonego
przez Godot DocTool.
</footer>

</body>
</html>
"@


    SaveUtf8 `
        -Path $HtmlPath `
        -Content $Html


    $Classes += [PSCustomObject]@{
        Name     = $ClassName
        File     = $HtmlFileName
        Inherits = $Inherits
        XmlFile  = $File.Name
    }


    Write-Host `
        "  Created: $HtmlFileName" `
        -ForegroundColor Green
}


# ------------------------------------------------------------
# Generate index.html
# ------------------------------------------------------------

$IndexItems = ""


foreach (
    $Item in (
        $Classes |
        Sort-Object Name
    )
) {

    $SafeName =
        HtmlEncode $Item.Name

    $HtmlUrl =
        [System.Uri]::EscapeDataString(
            $Item.File
        )

    $SafeParent =
        HtmlEncode $Item.Inherits


    $IndexItems += @"
<li>
<a href="$HtmlUrl">
<strong>$SafeName</strong>
</a>
"@


    if (
        -not [string]::IsNullOrWhiteSpace(
            $Item.Inherits
        )
    ) {

        $IndexItems += @"
<span class="meta">
(extends $SafeParent)
</span>
"@
    }


    $IndexItems += "</li>"
}


$ClassCount = $Classes.Count


$IndexHtml = @"
<!DOCTYPE html>
<html lang="pl">

<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">

<title>Dokumentacja kodu projektu</title>

$Css
</head>

<body>

<h1>Dokumentacja kodu projektu</h1>

<div class="info">
Dokumentacja zosta&#322;a wygenerowana na podstawie komentarzy
dokumentacyjnych GDScript. Godot DocTool wygenerowa&#322; dokumentacj&#281;
XML, kt&#243;ra nast&#281;pnie zosta&#322;a przekszta&#322;cona do HTML.
</div>

<p>
Liczba udokumentowanych klas/skrypt&#243;w:
<strong>$ClassCount</strong>
</p>

<h2>Klasy i skrypty</h2>

<ul class="class-list">
$IndexItems
</ul>

<h2>Oryginalna dokumentacja XML</h2>

<p>
Oryginalne pliki XML wygenerowane przez Godot s&#261;
dost&#281;pne w katalogu
<a href="xml/">xml</a>.
</p>

<footer>
Dokumentacja projektu Godot 4.4.
</footer>

</body>
</html>
"@


$IndexPath =
    Join-Path $DocsDir "index.html"


SaveUtf8 `
    -Path $IndexPath `
    -Content $IndexHtml


# ------------------------------------------------------------
# GitHub Pages .nojekyll
# ------------------------------------------------------------

$NoJekyllPath =
    Join-Path $DocsDir ".nojekyll"


SaveUtf8 `
    -Path $NoJekyllPath `
    -Content ""


# ------------------------------------------------------------
# Summary
# ------------------------------------------------------------

Write-Host ""
Write-Host "============================================"
Write-Host "DONE" -ForegroundColor Green
Write-Host "============================================"
Write-Host ""
Write-Host "Generated class pages: $ClassCount"
Write-Host ""
Write-Host "Main page:"
Write-Host $IndexPath -ForegroundColor Cyan
Write-Host ""
Write-Host "Open:"
Write-Host "docs\index.html" -ForegroundColor Cyan
Write-Host ""