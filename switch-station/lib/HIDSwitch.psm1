# HIDSwitch.psm1 — Logitech HID++ Change Host via Windows HID API
# Envia comando setCurrentHost para trocar canal Bluetooth de periféricos Logitech.

if (-not ([System.Management.Automation.PSTypeName]'HIDSwitch').Type) {
    Add-Type -TypeDefinition @"
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Collections.Generic;

public class HIDSwitch
{
    // ── Win32 HID imports ────────────────────────────────────────

    [DllImport("hid.dll")]
    private static extern void HidD_GetHidGuid(out Guid hidGuid);

    [DllImport("setupapi.dll", CharSet = CharSet.Auto)]
    private static extern IntPtr SetupDiGetClassDevs(
        ref Guid classGuid, IntPtr enumerator, IntPtr hwndParent, uint flags);

    [DllImport("setupapi.dll", CharSet = CharSet.Auto)]
    private static extern bool SetupDiEnumDeviceInterfaces(
        IntPtr hDevInfo, IntPtr devInfo, ref Guid interfaceClassGuid,
        uint memberIndex, ref SP_DEVICE_INTERFACE_DATA deviceInterfaceData);

    [DllImport("setupapi.dll", CharSet = CharSet.Auto)]
    private static extern bool SetupDiGetDeviceInterfaceDetail(
        IntPtr hDevInfo, ref SP_DEVICE_INTERFACE_DATA deviceInterfaceData,
        IntPtr deviceInterfaceDetailData, uint deviceInterfaceDetailDataSize,
        out uint requiredSize, IntPtr deviceInfoData);

    [DllImport("setupapi.dll")]
    private static extern bool SetupDiDestroyDeviceInfoList(IntPtr hDevInfo);

    [DllImport("hid.dll")]
    private static extern bool HidD_GetAttributes(IntPtr hidDeviceObject, ref HIDD_ATTRIBUTES attributes);

    [DllImport("hid.dll")]
    private static extern bool HidD_GetPreparsedData(IntPtr hidDeviceObject, out IntPtr preparsedData);

    [DllImport("hid.dll")]
    private static extern bool HidD_FreePreparsedData(IntPtr preparsedData);

    [DllImport("hid.dll")]
    private static extern int HidP_GetCaps(IntPtr preparsedData, out HIDP_CAPS capabilities);

    [DllImport("hid.dll")]
    private static extern bool HidD_SetOutputReport(IntPtr hidDeviceObject, byte[] reportBuffer, uint reportBufferLength);

    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr CreateFile(
        string fileName, uint desiredAccess, uint shareMode,
        IntPtr securityAttributes, uint creationDisposition,
        uint flagsAndAttributes, IntPtr templateFile);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool CloseHandle(IntPtr hObject);

    // ── Constants ────────────────────────────────────────────────

    private const uint DIGCF_PRESENT = 0x02;
    private const uint DIGCF_DEVICEINTERFACE = 0x10;
    private const uint GENERIC_WRITE = 0x40000000;
    private const uint GENERIC_READ = 0x80000000;
    private const uint FILE_SHARE_READ = 0x01;
    private const uint FILE_SHARE_WRITE = 0x02;
    private const uint OPEN_EXISTING = 3;
    private static readonly IntPtr INVALID_HANDLE = new IntPtr(-1);

    // ── Structs ──────────────────────────────────────────────────

    [StructLayout(LayoutKind.Sequential)]
    private struct SP_DEVICE_INTERFACE_DATA
    {
        public uint cbSize;
        public Guid InterfaceClassGuid;
        public uint Flags;
        public IntPtr Reserved;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct HIDD_ATTRIBUTES
    {
        public uint Size;
        public ushort VendorID;
        public ushort ProductID;
        public ushort VersionNumber;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct HIDP_CAPS
    {
        public ushort Usage;
        public ushort UsagePage;
        public ushort InputReportByteLength;
        public ushort OutputReportByteLength;
        public ushort FeatureReportByteLength;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 17)]
        public ushort[] Reserved;
        public ushort NumberLinkCollectionNodes;
        public ushort NumberInputButtonCaps;
        public ushort NumberInputValueCaps;
        public ushort NumberInputDataIndices;
        public ushort NumberOutputButtonCaps;
        public ushort NumberOutputValueCaps;
        public ushort NumberOutputDataIndices;
        public ushort NumberFeatureButtonCaps;
        public ushort NumberFeatureValueCaps;
        public ushort NumberFeatureDataIndices;
    }

    // ── Public API ───────────────────────────────────────────────

    /// <summary>
    /// Send HID++ Change Host command to a Logitech device.
    /// vendorId: 0x046D for Logitech
    /// productId: device PID (e.g. 0xB35B for MX Keys)
    /// featureIndex: HID++ feature index for Change Host (varies per device)
    /// hostIndex: 0 = channel 1, 1 = channel 2, 2 = channel 3
    /// </summary>
    public static bool ChangeHost(ushort vendorId, ushort productId, byte featureIndex, byte hostIndex)
    {
        // HID++ 2.0 long report: setCurrentHost (function 1)
        // Byte 0: Report ID (0x11 = long)
        // Byte 1: Device index (0x01)
        // Byte 2: Feature index
        // Byte 3: Function (1) << 4 | SW ID (0) = 0x10
        // Byte 4: Host index
        // Bytes 5-19: padding
        byte[] packet = new byte[20];
        packet[0] = 0x11;  // Long report
        packet[1] = 0x01;  // Device index
        packet[2] = featureIndex;
        packet[3] = 0x10;  // Function 1 (setCurrentHost) << 4
        packet[4] = hostIndex;

        return SendRawReport(vendorId, productId, packet);
    }

    /// <summary>
    /// Send a raw HID output report to a device matching VID/PID.
    /// Tries all matching interfaces until one succeeds.
    /// </summary>
    private static bool SendRawReport(ushort vendorId, ushort productId, byte[] report)
    {
        Guid hidGuid;
        HidD_GetHidGuid(out hidGuid);

        IntPtr hDevInfo = SetupDiGetClassDevs(
            ref hidGuid, IntPtr.Zero, IntPtr.Zero,
            DIGCF_PRESENT | DIGCF_DEVICEINTERFACE);

        if (hDevInfo == INVALID_HANDLE) return false;

        try
        {
            SP_DEVICE_INTERFACE_DATA ifData = new SP_DEVICE_INTERFACE_DATA();
            ifData.cbSize = (uint)Marshal.SizeOf(ifData);

            for (uint idx = 0; SetupDiEnumDeviceInterfaces(
                hDevInfo, IntPtr.Zero, ref hidGuid, idx, ref ifData); idx++)
            {
                // Get device path
                uint requiredSize;
                SetupDiGetDeviceInterfaceDetail(
                    hDevInfo, ref ifData, IntPtr.Zero, 0, out requiredSize, IntPtr.Zero);

                IntPtr detailData = Marshal.AllocHGlobal((int)requiredSize);
                try
                {
                    // Set cbSize for SP_DEVICE_INTERFACE_DETAIL_DATA
                    Marshal.WriteInt32(detailData, IntPtr.Size == 8 ? 8 : 6);

                    if (!SetupDiGetDeviceInterfaceDetail(
                        hDevInfo, ref ifData, detailData, requiredSize, out requiredSize, IntPtr.Zero))
                        continue;

                    string devicePath = Marshal.PtrToStringAuto(
                        new IntPtr(detailData.ToInt64() + 4));

                    // Open device and check VID/PID
                    IntPtr hDevice = CreateFile(devicePath,
                        GENERIC_WRITE | GENERIC_READ,
                        FILE_SHARE_READ | FILE_SHARE_WRITE,
                        IntPtr.Zero, OPEN_EXISTING, 0, IntPtr.Zero);

                    if (hDevice == INVALID_HANDLE) continue;

                    try
                    {
                        HIDD_ATTRIBUTES attrs = new HIDD_ATTRIBUTES();
                        attrs.Size = (uint)Marshal.SizeOf(attrs);

                        if (!HidD_GetAttributes(hDevice, ref attrs)) continue;
                        if (attrs.VendorID != vendorId || attrs.ProductID != productId) continue;

                        // Check output report length
                        IntPtr preparsedData;
                        if (!HidD_GetPreparsedData(hDevice, out preparsedData)) continue;

                        HIDP_CAPS caps;
                        HidP_GetCaps(preparsedData, out caps);
                        HidD_FreePreparsedData(preparsedData);

                        // We need an interface that accepts our report size
                        if (caps.OutputReportByteLength < report.Length) continue;

                        // Pad report to expected size
                        byte[] paddedReport = new byte[caps.OutputReportByteLength];
                        Array.Copy(report, paddedReport, report.Length);

                        if (HidD_SetOutputReport(hDevice, paddedReport, (uint)paddedReport.Length))
                            return true;
                    }
                    finally
                    {
                        CloseHandle(hDevice);
                    }
                }
                finally
                {
                    Marshal.FreeHGlobal(detailData);
                }
            }
        }
        finally
        {
            SetupDiDestroyDeviceInfoList(hDevInfo);
        }

        return false;
    }
}
"@
}
