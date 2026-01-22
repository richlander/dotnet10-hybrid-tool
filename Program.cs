using System.Runtime.InteropServices;

var runtime = RuntimeInformation.FrameworkDescription;
var rid = RuntimeInformation.RuntimeIdentifier;

#if NATIVE_AOT
const string mode = "Native AOT (compile-time)";
#else
const string mode = "CoreCLR (compile-time)";
#endif

Console.WriteLine("Hello from hellorid!");
Console.WriteLine($"Runtime: {runtime}");
Console.WriteLine($"RID: {rid}");
Console.WriteLine($"Mode: {mode}");
