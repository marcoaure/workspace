# DDC.psm1 — DDC/CI Monitor Control via Windows API (dxva2.dll)
# Permite ler e trocar input de monitores sem ferramentas externas.

if (-not ([System.Management.Automation.PSTypeName]'DDCMonitor').Type) {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Collections.Generic;

public class DDCMonitor
{
    // ── Win32 imports ──────────────────────────────────────────────

    [DllImport("user32.dll")]
    private static extern bool EnumDisplayMonitors(
        IntPtr hdc, IntPtr lprcClip,
        MonitorEnumDelegate lpfnEnum, IntPtr dwData);

    [DllImport("dxva2.dll")]
    private static extern bool GetNumberOfPhysicalMonitorsFromHMONITOR(
        IntPtr hMonitor, out uint pdwNumberOfPhysicalMonitors);

    [DllImport("dxva2.dll")]
    private static extern bool GetPhysicalMonitorsFromHMONITOR(
        IntPtr hMonitor, uint dwPhysicalMonitorArraySize,
        [Out] PHYSICAL_MONITOR[] pPhysicalMonitorArray);

    [DllImport("dxva2.dll")]
    private static extern bool SetVCPFeature(
        IntPtr hMonitor, byte bVCPCode, uint dwNewValue);

    [DllImport("dxva2.dll")]
    private static extern bool GetVCPFeatureAndVCPFeatureReply(
        IntPtr hMonitor, byte bVCPCode,
        out uint pvct, out uint pdwCurrentValue, out uint pdwMaximumValue);

    [DllImport("dxva2.dll")]
    private static extern bool DestroyPhysicalMonitor(IntPtr hMonitor);

    // ── Types ──────────────────────────────────────────────────────

    private delegate bool MonitorEnumDelegate(
        IntPtr hMonitor, IntPtr hdcMonitor,
        ref RECT lprcMonitor, IntPtr dwData);

    [StructLayout(LayoutKind.Sequential)]
    private struct RECT { public int left, top, right, bottom; }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct PHYSICAL_MONITOR
    {
        public IntPtr hPhysicalMonitor;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
        public string szPhysicalMonitorDescription;
    }

    // ── Enumeration ────────────────────────────────────────────────

    private static List<PHYSICAL_MONITOR> _monitors = new List<PHYSICAL_MONITOR>();

    private static bool MonitorEnum(IntPtr hMonitor, IntPtr hdcMonitor,
        ref RECT lprcMonitor, IntPtr dwData)
    {
        uint count;
        GetNumberOfPhysicalMonitorsFromHMONITOR(hMonitor, out count);
        var arr = new PHYSICAL_MONITOR[count];
        GetPhysicalMonitorsFromHMONITOR(hMonitor, count, arr);
        for (int i = 0; i < arr.Length; i++)
            _monitors.Add(arr[i]);
        return true;
    }

    /// <summary>Enumerate all physical monitors connected to the system.</summary>
    public static PHYSICAL_MONITOR[] GetAll()
    {
        _monitors.Clear();
        EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, MonitorEnum, IntPtr.Zero);
        return _monitors.ToArray();
    }

    // ── VCP 0x60  Input Select ─────────────────────────────────────

    /// <summary>Read current input source (VCP 0x60).</summary>
    public static uint GetInput(IntPtr handle)
    {
        uint pvct, current, max;
        if (GetVCPFeatureAndVCPFeatureReply(handle, 0x60, out pvct, out current, out max))
            return current;
        return 0;
    }

    /// <summary>Set input source (VCP 0x60).</summary>
    public static bool SetInput(IntPtr handle, uint value)
    {
        return SetVCPFeature(handle, 0x60, value);
    }

    /// <summary>Read any VCP code.</summary>
    public static uint GetVCP(IntPtr handle, byte code)
    {
        uint pvct, current, max;
        if (GetVCPFeatureAndVCPFeatureReply(handle, code, out pvct, out current, out max))
            return current;
        return 0;
    }

    /// <summary>Write any VCP code.</summary>
    public static bool SetVCP(IntPtr handle, byte code, uint value)
    {
        return SetVCPFeature(handle, code, value);
    }

    // ── Cleanup ────────────────────────────────────────────────────

    public static void Release(IntPtr handle)
    {
        DestroyPhysicalMonitor(handle);
    }
}
"@
}
