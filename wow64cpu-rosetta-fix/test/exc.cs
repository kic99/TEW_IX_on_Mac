using System;
class P { static void Main() {
  Console.WriteLine("start, 64bit=" + Environment.Is64BitProcess + " clr=" + Environment.Version);
  try { throw new InvalidOperationException("managed"); } catch (Exception e) { Console.WriteLine("caught managed: " + e.Message); }
  try { object o = null; o.ToString(); } catch (Exception e) { Console.WriteLine("caught nullref: " + e.GetType().Name); }
  Console.WriteLine("done");
}}
