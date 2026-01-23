using System.Runtime.InteropServices;

var runtime = RuntimeInformation.FrameworkDescription;
var rid = RuntimeInformation.RuntimeIdentifier;

#if NATIVE_AOT
const string mode = "Native AOT";
#else
const string mode = "CoreCLR";
#endif

Console.WriteLine("Hi, I'm a 'DotNetCliTool v2' tool!");
Console.WriteLine("Yes, I'm quite fancy.");
Console.WriteLine();
Console.WriteLine($"Version: {runtime}");
Console.WriteLine($"RID: {rid}");
Console.WriteLine($"Mode: {mode}");
