# DisplayControl.psm1 — Attach/Detach individual displays via Win32 API

if (-not ([System.Management.Automation.PSTypeName]'DisplayControl').Type) {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class DisplayControl
{
    private const int ENUM_CURRENT_SETTINGS = -1;
    private const int CDS_UPDATEREGISTRY = 0x01;
    private const int CDS_NORESET = 0x10000000;
    private const int DM_PELSWIDTH = 0x80000;
    private const int DM_PELSHEIGHT = 0x100000;
    private const int DM_POSITION = 0x20;
    private const int DISP_CHANGE_SUCCESSFUL = 0;

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern bool EnumDisplayDevices(
        string lpDevice, uint iDevNum, ref DISPLAY_DEVICE lpDisplayDevice, uint dwFlags);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern bool EnumDisplaySettings(
        string lpszDeviceName, int iModeNum, ref DEVMODE lpDevMode);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int ChangeDisplaySettingsEx(
        string lpszDeviceName, IntPtr lpDevMode, IntPtr hwnd,
        uint dwflags, IntPtr lParam);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int ChangeDisplaySettingsExDM(
        string lpszDeviceName, ref DEVMODE lpDevMode, IntPtr hwnd,
        uint dwflags, IntPtr lParam);

    // Rename for P/Invoke overload
    [DllImport("user32.dll", CharSet = CharSet.Unicode, EntryPoint = "ChangeDisplaySettingsEx")]
    private static extern int ChangeDisplaySettingsExRef(
        string lpszDeviceName, ref DEVMODE lpDevMode, IntPtr hwnd,
        uint dwflags, IntPtr lParam);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct DISPLAY_DEVICE
    {
        public int cb;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string DeviceName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
        public string DeviceString;
        public int StateFlags;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
        public string DeviceID;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
        public string DeviceKey;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct DEVMODE
    {
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string dmDeviceName;
        public short dmSpecVersion;
        public short dmDriverVersion;
        public short dmSize;
        public short dmDriverExtra;
        public int dmFields;
        public int dmPositionX;
        public int dmPositionY;
        public int dmDisplayOrientation;
        public int dmDisplayFixedOutput;
        public short dmColor;
        public short dmDuplex;
        public short dmYResolution;
        public short dmTTOption;
        public short dmCollate;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string dmFormName;
        public short dmLogPixels;
        public int dmBitsPerPel;
        public int dmPelsWidth;
        public int dmPelsHeight;
        public int dmDisplayFlags;
        public int dmDisplayFrequency;
        public int dmICMMethod;
        public int dmICMIntent;
        public int dmMediaType;
        public int dmDitherType;
        public int dmReserved1;
        public int dmReserved2;
        public int dmPanningWidth;
        public int dmPanningHeight;
    }

    /// <summary>List active display adapters.</summary>
    public static string[] ListDisplays()
    {
        var result = new System.Collections.Generic.List<string>();
        var dd = new DISPLAY_DEVICE();
        dd.cb = Marshal.SizeOf(dd);
        uint i = 0;
        while (EnumDisplayDevices(null, i, ref dd, 0))
        {
            bool active = (dd.StateFlags & 1) != 0; // DISPLAY_DEVICE_ATTACHED_TO_DESKTOP
            var ddMon = new DISPLAY_DEVICE();
            ddMon.cb = Marshal.SizeOf(ddMon);
            EnumDisplayDevices(dd.DeviceName, 0, ref ddMon, 0);
            result.Add(dd.DeviceName + " | " + dd.DeviceString + " | Monitor: " + ddMon.DeviceString + " | Active: " + active);
            dd.cb = Marshal.SizeOf(dd);
            i++;
        }
        return result.ToArray();
    }

    /// <summary>Detach a display (cut signal). Returns 0 on success.</summary>
    public static int Detach(string deviceName)
    {
        var dm = new DEVMODE();
        dm.dmSize = (short)Marshal.SizeOf(typeof(DEVMODE));
        dm.dmPelsWidth = 0;
        dm.dmPelsHeight = 0;
        dm.dmPositionX = 0;
        dm.dmPositionY = 0;
        dm.dmFields = DM_PELSWIDTH | DM_PELSHEIGHT | DM_POSITION;

        int r1 = ChangeDisplaySettingsExRef(deviceName, ref dm, IntPtr.Zero,
            CDS_UPDATEREGISTRY | CDS_NORESET, IntPtr.Zero);
        if (r1 != DISP_CHANGE_SUCCESSFUL) return r1;

        // Apply changes
        int r2 = ChangeDisplaySettingsEx(null, IntPtr.Zero, IntPtr.Zero, 0, IntPtr.Zero);
        return r2;
    }

    /// <summary>Reattach a display with given resolution. Returns 0 on success.</summary>
    public static int Attach(string deviceName, int width, int height, int posX, int posY, int freq)
    {
        var dm = new DEVMODE();
        dm.dmSize = (short)Marshal.SizeOf(typeof(DEVMODE));
        dm.dmPelsWidth = width;
        dm.dmPelsHeight = height;
        dm.dmPositionX = posX;
        dm.dmPositionY = posY;
        dm.dmDisplayFrequency = freq;
        dm.dmFields = DM_PELSWIDTH | DM_PELSHEIGHT | DM_POSITION | 0x400000; // DM_DISPLAYFREQUENCY

        int r1 = ChangeDisplaySettingsExRef(deviceName, ref dm, IntPtr.Zero,
            CDS_UPDATEREGISTRY | CDS_NORESET, IntPtr.Zero);
        if (r1 != DISP_CHANGE_SUCCESSFUL) return r1;

        int r2 = ChangeDisplaySettingsEx(null, IntPtr.Zero, IntPtr.Zero, 0, IntPtr.Zero);
        return r2;
    }

    /// <summary>Get current DEVMODE info for a display.</summary>
    public static string GetInfo(string deviceName)
    {
        var dm = new DEVMODE();
        dm.dmSize = (short)Marshal.SizeOf(typeof(DEVMODE));
        if (EnumDisplaySettings(deviceName, ENUM_CURRENT_SETTINGS, ref dm))
        {
            return deviceName + " : " + dm.dmPelsWidth + "x" + dm.dmPelsHeight +
                " @ " + dm.dmDisplayFrequency + "Hz" +
                " pos(" + dm.dmPositionX + "," + dm.dmPositionY + ")";
        }
        return deviceName + " : detached or unavailable";
    }
}
"@
}
