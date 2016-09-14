$root = $MyInvocation.MyCommand.Definition | Split-Path -Parent;
$vsroot = "$root\src\Microsoft.VisualStudio.VsInteractiveWindow";
$editorroot = "$root\src\Microsoft.VisualStudio.InteractiveWindow";

$enc = New-Object System.Text.UTF8Encoding($True);

$vsct = [xml](gc $vsroot\InteractiveWindow.vsct)
$ct = $vsct.CommandTable;

"Update GUIDs in VSCT file"
foreach ($s in ($ct.KeyBindings.KeyBinding | ?{ $_.editor -eq "guidCSharpEditorFactory" })) {
    $ct.KeyBindings.RemoveChild($s) | Out-Null;
}
foreach ($s in ($ct.Symbols.Symbol | ?{ $_.name -eq "guidCSharpEditorFactory" })) {
    $ct.Symbols.RemoveChild($s) | Out-Null;
}
foreach ($s in ($ct.Buttons.Button | ?{ $_.name -eq "cmdidExecuteInInteractiveWindow" -or $_.name -eq "cmdidCopyToInteractiveWindow" })) {
    $cs.Buttons.RemoveChild($s) | Out-Null;
}

foreach ($s in $ct.Symbols.GuidSymbol) {
    if ($s.name -eq "guidInteractiveWindowPkg") {
        $s.value = "{72FDA47E-B202-4BAB-8AD9-0FB0F33A5015}";
    } elseif ($s.name -eq "guidInteractiveWindow") {
        $s.value =  "{4C65B4B3-E8C7-46E8-AB0E-DA1CE46DA7EC}";
    } elseif ($s.name -eq "guidInteractiveWindowCmdSet") {
        $s.value = "{F27554FA-3DF4-4649-A81C-1B97C932E78B}";
    }
}
foreach ($s in $ct.Commands.Buttons.Button.Strings) {
    $s.CanonicalName = $s.CanonicalName -replace '\.InteractiveConsole\.(\w+)', '.PythonInteractiveConsole.$1'
    $s.LocCanonicalName = $s.LocCanonicalName -replace '\.InteractiveConsole\.(\w+)', '.PythonInteractiveConsole.$1'
}

$vsct.Save("$vsroot\InteractiveWindow.vsct");

"Update items in extension.vsixmanifest"
$vsix = [xml](gc $vsroot\source.extension.vsixmanifest)
$vsix.PackageManifest.Metadata.Identity.Id = "045BB34E-CAF1-45D8-8103-BF029D5A78A5";
$vsix.PackageManifest.Metadata.DisplayName = "Python Tools Interactive Window Components";
$vsix.Save("$vsroot\source.extension.vsixmanifest")

"Update GUIDs in Guids.cs"
[System.IO.File]::WriteAllLines(
    "$vsroot\Guids.cs",
    ((gc $vsroot\Guids.cs) |
        %{ $_ -replace 'InteractiveToolWindowIdString = "[\w\-]+"', 'InteractiveToolWindowIdString = "4C65B4B3-E8C7-46E8-AB0E-DA1CE46DA7EC"' } |
        %{ $_ -replace 'InteractiveWindowPackageIdString = "[\w\-]+"', 'InteractiveWindowPackageIdString = "72FDA47E-B202-4BAB-8AD9-0FB0F33A5015"' } |
        %{ $_ -replace 'InteractiveCommandSetIdString = "[\w\-]+"', 'InteractiveCommandSetIdString = "F27554FA-3DF4-4649-A81C-1B97C932E78B"' }),
    $enc
)

"Update VSInteractiveWindow project"
$proj = [xml](gc $vsroot\VsInteractiveWindow.csproj)

foreach ($e in $proj.Project.PropertyGroup) {
    if ($e.RootNamespace) {
        $e.RootNamespace = "Microsoft.PythonTools";
    }
    if ($e.AssemblyName) {
        $e.AssemblyName = "Microsoft.PythonTools.VsInteractiveWindow";
    }
}

foreach ($s in $proj.Project.ImportGroup.Import) {
    if ($s.Project -match 'VSL\.Settings\.targets$') {
        $s.Project = "..\Before.targets";
    } elseif ($s.Project -match 'VSL\.Imports\.targets$') {
        $s.Project = "..\After.targets";
    }
}

foreach ($e in $proj.Project.ItemGroup) {
    #foreach ($s in ($e.ProjectReference | ?{ $_.Include -match 'VisualStudio\.csproj$'})) {
    #    $e.RemoveChild($s) | Out-Null;
    #}
    #foreach ($s in ($e.ProjectReference | ?{ $_.Include -match 'Editor\\InteractiveWindow\.csproj$'})) {
    #    $s.Include = '..\Editor\InteractiveWindow.csproj';
    #}
    foreach ($s in ($e.Compile | ?{ $_.Include -match 'ProvideBindingRedirection\.cs$' -or $_.Include -match 'AssemblyRedirects\.cs$'})) {
        $e.RemoveChild($s) | Out-Null;
    }
}

$proj.Save("$vsroot\VsInteractiveWindow.csproj")

"Update InteractiveWindow project"
$proj = [xml](gc $editorroot\InteractiveWindow.csproj)

foreach ($e in $proj.Project.PropertyGroup) {
    if ($e.RootNamespace) {
        $e.RootNamespace = "Microsoft.PythonTools.InteractiveWindow";
    }
    if ($e.AssemblyName) {
        $e.AssemblyName = "Microsoft.PythonTools.InteractiveWindow";
    }
}

#foreach ($s in $proj.Project.ImportGroup.Import) {
#    if ($s.Project -match 'VSL\.Settings\.targets$') {
#        $s.Project = "..\Before.targets";
#    } elseif ($s.Project -match 'VSL\.Imports\.targets$') {
#        $s.Project = "..\After.targets";
#    }
#}

#foreach ($e in $proj.Project.ItemGroup) {
#    foreach ($s in $e.ProjectReference) {
#        $e.RemoveChild($s) | Out-Null;
#    }
#    foreach ($s in $e.Compile) {
#        if ($s.Include -match '\.\.\\\.\.\\Compilers\\Core\\Portable\\InternalUtilities\\(.+)$') {
#            $s.Include = '..\' + $Matches[1];
#        }
#    }
#}

$proj.Save("$editorroot\InteractiveWindow.csproj")

"Update namespaces in source files"
gci "$vsroot\*.cs", "$editorroot\*.cs" -r | %{
    [System.IO.File]::WriteAllLines($_, ((gc $_) | 
        %{ $_ -replace 'namespace Microsoft\.VisualStudio', 'using Microsoft.VisualStudio;
namespace Microsoft.PythonTools' } |
        %{ $_ -replace 'Microsoft\.VisualStudio\.InteractiveWindow', 'Microsoft.PythonTools.InteractiveWindow' } |
        %{ $_ -replace 'Microsoft\.VisualStudio\.VsInteractiveWindow', 'Microsoft.PythonTools.VsInteractiveWindow' } |
        %{ $_ -replace '\(int\)OLE\.', '(int)Microsoft.VisualStudio.OLE.' }
    ), $enc);
}

[System.IO.File]::WriteAllLines("$editorroot\SmartUpDownOption.cs", ((gc "$editorroot\SmartUpDownOption.cs") |
    %{ $_ -replace 'OptionName = ".+";', 'OptionName = "PythonInteractiveSmartUpDown";' }
), $enc);
[System.IO.File]::WriteAllLines("$editorroot\PredefinedInteractiveContentTypes.cs", ((gc "$editorroot\PredefinedInteractiveContentTypes.cs") |
    %{ $_ -replace '(\w+) = "(Interactive .+)";', '$1 = "Python $2";' }
), $enc);
[System.IO.File]::WriteAllLines("$editorroot\Output\OutputClassifierProvider.cs", ((gc "$editorroot\Output\OutputClassifierProvider.cs") |
    %{ $_ -replace 'Name = "(Interactive .+)";', 'Name = "Python $1";' }
), $enc);
[System.IO.File]::WriteAllLines("$editorroot\Commands\PredefinedInteractiveCommandsContentTypes.cs", ((gc "$editorroot\Commands\PredefinedInteractiveCommandsContentTypes.cs") |
    %{ $_ -replace 'Name = "(Interactive .+)";', 'Name = "Python $1";' }
), $enc);

"Disable test build"
[System.IO.File]::WriteAllLines("$root\InteractiveWindow.sln", ((gc "$root\InteractiveWindow.sln") |
    ?{ -not ($_ -match '{7F3CB45E-4993-4FA4-8D6A-C2DFFED2DFC3}\.\w+\|(x86|x64|Any CPU).Build.0 = .+') }
));

"Finished! Ready to build"
