# discover-hid.ps1 — Descobre feature index do HID++ Change Host em perifericos Logitech
# Rode: powershell -ExecutionPolicy Bypass -File .\discover-hid.ps1

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module "$scriptDir\lib\HIDSwitch.psm1" -Force

# Carregar config
$configPath = Join-Path $scriptDir "config.json"
$config = Get-Content $configPath -Raw | ConvertFrom-Json

Write-Host ""
Write-Host "  === HID++ Peripheral Discovery ===" -ForegroundColor Cyan
Write-Host ""

# Adicionar metodo de discovery ao modulo inline
Add-Type -TypeDefinition @"
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;

public class HIDQuery
{
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

    [DllImport("hid.dll")]
    private static extern bool HidD_GetInputReport(IntPtr hidDeviceObject, byte[] reportBuffer, uint reportBufferLength);

    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr CreateFile(
        string fileName, uint desiredAccess, uint shareMode,
        IntPtr securityAttributes, uint creationDisposition,
        uint flagsAndAttributes, IntPtr templateFile);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool CloseHandle(IntPtr hObject);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool ReadFile(IntPtr hFile, byte[] lpBuffer, uint nNumberOfBytesToRead,
        out uint lpNumberOfBytesRead, IntPtr lpOverlapped);

    private const uint DIGCF_PRESENT = 0x02;
    private const uint DIGCF_DEVICEINTERFACE = 0x10;
    private const uint GENERIC_WRITE = 0x40000000;
    private const uint GENERIC_READ = 0x80000000;
    private const uint FILE_SHARE_READ = 0x01;
    private const uint FILE_SHARE_WRITE = 0x02;
    private const uint OPEN_EXISTING = 3;
    private const uint FILE_FLAG_OVERLAPPED = 0x40000000;
    private static readonly IntPtr INVALID_HANDLE = new IntPtr(-1);

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

    /// <summary>
    /// Query HID++ feature index for a given featureID on a device.
    /// Returns the feature index, or -1 if not found.
    /// </summary>
    public static int QueryFeatureIndex(ushort vendorId, ushort productId, ushort featureId)
    {
        Guid hidGuid;
        HidD_GetHidGuid(out hidGuid);

        IntPtr hDevInfo = SetupDiGetClassDevs(
            ref hidGuid, IntPtr.Zero, IntPtr.Zero,
            DIGCF_PRESENT | DIGCF_DEVICEINTERFACE);

        if (hDevInfo == INVALID_HANDLE) return -1;

        try
        {
            SP_DEVICE_INTERFACE_DATA ifData = new SP_DEVICE_INTERFACE_DATA();
            ifData.cbSize = (uint)Marshal.SizeOf(ifData);

            for (uint idx = 0; SetupDiEnumDeviceInterfaces(
                hDevInfo, IntPtr.Zero, ref hidGuid, idx, ref ifData); idx++)
            {
                uint requiredSize;
                SetupDiGetDeviceInterfaceDetail(
                    hDevInfo, ref ifData, IntPtr.Zero, 0, out requiredSize, IntPtr.Zero);

                IntPtr detailData = Marshal.AllocHGlobal((int)requiredSize);
                try
                {
                    Marshal.WriteInt32(detailData, IntPtr.Size == 8 ? 8 : 6);

                    if (!SetupDiGetDeviceInterfaceDetail(
                        hDevInfo, ref ifData, detailData, requiredSize, out requiredSize, IntPtr.Zero))
                        continue;

                    string devicePath = Marshal.PtrToStringAuto(
                        new IntPtr(detailData.ToInt64() + 4));

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

                        IntPtr preparsedData;
                        if (!HidD_GetPreparsedData(hDevice, out preparsedData)) continue;

                        HIDP_CAPS caps;
                        HidP_GetCaps(preparsedData, out caps);
                        HidD_FreePreparsedData(preparsedData);

                        if (caps.OutputReportByteLength < 20) continue;

                        // Send IRoot getFeatureID query
                        byte[] query = new byte[caps.OutputReportByteLength];
                        query[0] = 0x11;  // Report ID: long
                        query[1] = 0x01;  // Device index
                        query[2] = 0x00;  // IRoot feature
                        query[3] = 0x00;  // Function 0 = getFeatureID
                        query[4] = (byte)(featureId >> 8);
                        query[5] = (byte)(featureId & 0xFF);

                        if (!HidD_SetOutputReport(hDevice, query, (uint)query.Length))
                            continue;

                        // Try to read response
                        Thread.Sleep(100);
                        byte[] response = new byte[caps.InputReportByteLength];
                        response[0] = 0x11; // Report ID we want
                        if (HidD_GetInputReport(hDevice, response, (uint)response.Length))
                        {
                            // Check if response matches our query
                            if (response[0] == 0x11 && response[2] == 0x00)
                            {
                                int featureIdx = response[4];
                                return featureIdx;
                            }
                        }
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

        return -1;
    }
}
"@

foreach ($periph in $config.peripherals) {
    $devVid = [Convert]::ToUInt16($periph.vid, 16)
    $devPid = [Convert]::ToUInt16($periph.pid, 16)

    Write-Host "  $($periph.name) ($($periph.vid):$($periph.pid))" -ForegroundColor Yellow
    Write-Host "    Config feature index: $($periph.change_host_feature_index)"

    try {
        # Query feature 0x1814 (Change Host)
        $featureIdx = [HIDQuery]::QueryFeatureIndex($devVid, $devPid, 0x1814)
        if ($featureIdx -ge 0) {
            Write-Host "    Windows feature index: $featureIdx (0x$('{0:X2}' -f $featureIdx))" -ForegroundColor Green
            if ($featureIdx -ne $periph.change_host_feature_index) {
                Write-Host "    *** DIFERENTE DO CONFIG! Atualizar config.json ***" -ForegroundColor Red
            } else {
                Write-Host "    [OK] Igual ao config" -ForegroundColor Green
            }
        } else {
            Write-Host "    Nao conseguiu descobrir (device nao respondeu)" -ForegroundColor Red
        }
    } catch {
        Write-Host "    ERRO: $_" -ForegroundColor Red
    }
    Write-Host ""
}

Write-Host "  Se os feature indexes forem diferentes, atualize config.json" -ForegroundColor DarkGray
Write-Host "  e adicione campos separados: win_feature_index / mac_feature_index" -ForegroundColor DarkGray
Write-Host ""
