// Stream Fantasma - abre uma sessao REAL de captura de tela (Desktop Duplication API,
// a mesma que o Discord/OBS usam) e joga todo frame no lixo. Nao codifica, nao grava,
// nao envia nada. O objetivo e' unico: fazer o Windows sair do Independent Flip e
// compor a tela num plano so' - o que corrige o cursor de hardware bugado.
//
// Ctrl+C ou fechar a janela encerra.

using System;
using System.Runtime.InteropServices;
using System.Threading;

namespace StreamFantasma
{
    [StructLayout(LayoutKind.Sequential)]
    public struct POINT { public int x; public int y; }

    [StructLayout(LayoutKind.Sequential)]
    public struct DXGI_OUTDUPL_POINTER_POSITION { public POINT Position; public int Visible; }

    [StructLayout(LayoutKind.Sequential)]
    public struct DXGI_OUTDUPL_FRAME_INFO
    {
        public long LastPresentTime;
        public long LastMouseUpdateTime;
        public uint AccumulatedFrames;
        public int RectsCoalesced;
        public int ProtectedContentMaskedOut;
        public DXGI_OUTDUPL_POINTER_POSITION PointerPosition;
        public uint TotalMetadataBufferSize;
        public uint PointerShapeBufferSize;
    }

    [ComImport, Guid("770aae78-f26f-4dba-a829-253c83d1b387"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IDXGIFactory1
    {
        // IDXGIObject
        void SetPrivateData();
        void SetPrivateDataInterface();
        void GetPrivateData();
        void GetParent();
        // IDXGIFactory
        void EnumAdapters();
        void MakeWindowAssociation();
        void GetWindowAssociation();
        void CreateSwapChain();
        void CreateSoftwareAdapter();
        // IDXGIFactory1
        [PreserveSig] int EnumAdapters1(uint Adapter, out IDXGIAdapter1 ppAdapter);
        void IsCurrent();
    }

    [ComImport, Guid("29038f61-3839-4626-91fd-086879011a05"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IDXGIAdapter1
    {
        // IDXGIObject
        void SetPrivateData();
        void SetPrivateDataInterface();
        void GetPrivateData();
        void GetParent();
        // IDXGIAdapter
        [PreserveSig] int EnumOutputs(uint Output, out IDXGIOutput ppOutput);
        void GetDesc();
        void CheckInterfaceSupport();
        // IDXGIAdapter1
        void GetDesc1();
    }

    [ComImport, Guid("ae02eedb-c735-4690-8d52-5a8dc20213aa"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IDXGIOutput
    {
        void SetPrivateData();
        void SetPrivateDataInterface();
        void GetPrivateData();
        void GetParent();
        void GetDesc();
        void GetDisplayModeList();
        void FindClosestMatchingMode();
        void WaitForVBlank();
        void TakeOwnership();
        void ReleaseOwnership();
        void GetGammaControlCapabilities();
        void SetGammaControl();
        void GetGammaControl();
        void SetDisplaySurface();
        void GetDisplaySurfaceData();
        void GetFrameStatistics();
    }

    [ComImport, Guid("00cddea8-939b-4b83-a340-a685226666cc"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IDXGIOutput1
    {
        void SetPrivateData();
        void SetPrivateDataInterface();
        void GetPrivateData();
        void GetParent();
        void GetDesc();
        void GetDisplayModeList();
        void FindClosestMatchingMode();
        void WaitForVBlank();
        void TakeOwnership();
        void ReleaseOwnership();
        void GetGammaControlCapabilities();
        void SetGammaControl();
        void GetGammaControl();
        void SetDisplaySurface();
        void GetDisplaySurfaceData();
        void GetFrameStatistics();
        // IDXGIOutput1
        void GetDisplayModeList1();
        void FindClosestMatchingMode1();
        void GetDisplaySurfaceData1();
        [PreserveSig] int DuplicateOutput(IntPtr pDevice, out IDXGIOutputDuplication ppOutputDuplication);
    }

    [ComImport, Guid("191cfac3-a341-470d-b26e-a864f428319c"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IDXGIOutputDuplication
    {
        void SetPrivateData();
        void SetPrivateDataInterface();
        void GetPrivateData();
        void GetParent();
        void GetDesc();
        [PreserveSig] int AcquireNextFrame(uint TimeoutInMilliseconds, out DXGI_OUTDUPL_FRAME_INFO pFrameInfo, out IntPtr ppDesktopResource);
        void GetFrameDirtyRects();
        void GetFrameMoveRects();
        void GetFramePointerShape();
        void MapDesktopSurface();
        void UnMapDesktopSurface();
        [PreserveSig] int ReleaseFrame();
    }

    public static class Program
    {
        [DllImport("d3d11.dll")]
        static extern int D3D11CreateDevice(
            IntPtr pAdapter, int DriverType, IntPtr Software, uint Flags,
            IntPtr pFeatureLevels, uint FeatureLevels, uint SDKVersion,
            out IntPtr ppDevice, out int pFeatureLevel, out IntPtr ppImmediateContext);

        [DllImport("dxgi.dll")]
        static extern int CreateDXGIFactory1(ref Guid riid, out IDXGIFactory1 ppFactory);

        const int DXGI_ERROR_WAIT_TIMEOUT = unchecked((int)0x887A0027);
        const int DXGI_ERROR_ACCESS_LOST = unchecked((int)0x887A0026);
        const int D3D_DRIVER_TYPE_HARDWARE = 1;
        const uint D3D11_SDK_VERSION = 7;

        static volatile bool rodando = true;

        public static int Main(string[] args)
        {
            uint saidaIdx = 0;
            if (args.Length > 0) uint.TryParse(args[0], out saidaIdx);

            Console.Title = "Stream Fantasma";
            Console.WriteLine("=== STREAM FANTASMA ===");
            Console.WriteLine("Sessao de captura REAL, frames descartados. Nada e' gravado ou enviado.");
            Console.WriteLine();

            Console.CancelKeyPress += delegate (object s, ConsoleCancelEventArgs e) {
                e.Cancel = true; rodando = false;
            };

            IntPtr device, ctx; int fl;
            int hr = D3D11CreateDevice(IntPtr.Zero, D3D_DRIVER_TYPE_HARDWARE, IntPtr.Zero, 0,
                                       IntPtr.Zero, 0, D3D11_SDK_VERSION, out device, out fl, out ctx);
            if (hr < 0) { Console.WriteLine("ERRO: D3D11CreateDevice falhou (0x" + hr.ToString("X8") + ")"); return 1; }
            Console.WriteLine("[ok] dispositivo D3D11 criado");

            Guid iidFactory1 = new Guid("770aae78-f26f-4dba-a829-253c83d1b387");
            IDXGIFactory1 factory;
            hr = CreateDXGIFactory1(ref iidFactory1, out factory);
            if (hr < 0) { Console.WriteLine("ERRO: CreateDXGIFactory1 falhou (0x" + hr.ToString("X8") + ")"); return 1; }

            IDXGIAdapter1 adapter;
            hr = factory.EnumAdapters1(0, out adapter);
            if (hr < 0) { Console.WriteLine("ERRO: EnumAdapters1 falhou (0x" + hr.ToString("X8") + ")"); return 1; }
            Console.WriteLine("[ok] adaptador 0 obtido");

            IDXGIOutput output;
            hr = adapter.EnumOutputs(saidaIdx, out output);
            if (hr < 0) { Console.WriteLine("ERRO: nao achei a saida de video " + saidaIdx + " (0x" + hr.ToString("X8") + ")"); return 1; }
            Console.WriteLine("[ok] saida de video " + saidaIdx + " obtida");

            IDXGIOutput1 output1 = (IDXGIOutput1)output;
            IDXGIOutputDuplication dupl;
            hr = output1.DuplicateOutput(device, out dupl);
            if (hr < 0) { Console.WriteLine("ERRO: DuplicateOutput falhou (0x" + hr.ToString("X8") + ")"); return 1; }

            Console.WriteLine("[ok] SESSAO DE CAPTURA ATIVA na saida " + saidaIdx);
            Console.WriteLine();
            Console.WriteLine(">>> Vai olhar o cursor no Dota agora. Ctrl+C encerra. <<<");
            Console.WriteLine();

            long frames = 0, timeouts = 0;
            DateTime ultimoLog = DateTime.Now;

            while (rodando)
            {
                DXGI_OUTDUPL_FRAME_INFO info; IntPtr res;
                hr = dupl.AcquireNextFrame(500, out info, out res);

                if (hr == DXGI_ERROR_WAIT_TIMEOUT) { timeouts++; continue; }

                if (hr == DXGI_ERROR_ACCESS_LOST)
                {
                    Console.WriteLine("[!] sessao perdida (troca de modo). Recriando...");
                    try { Marshal.ReleaseComObject(dupl); } catch { }
                    Thread.Sleep(200);
                    hr = output1.DuplicateOutput(device, out dupl);
                    if (hr < 0) { Console.WriteLine("ERRO: nao consegui recriar (0x" + hr.ToString("X8") + ")"); return 1; }
                    Console.WriteLine("[ok] sessao recriada");
                    continue;
                }

                if (hr < 0) { Console.WriteLine("ERRO: AcquireNextFrame (0x" + hr.ToString("X8") + ")"); return 1; }

                frames++;
                if (res != IntPtr.Zero) Marshal.Release(res);   // frame no lixo
                dupl.ReleaseFrame();

                if ((DateTime.Now - ultimoLog).TotalSeconds >= 10)
                {
                    Console.WriteLine("   ativo | frames descartados: " + frames + " | esperas: " + timeouts);
                    ultimoLog = DateTime.Now;
                }
            }

            Console.WriteLine();
            Console.WriteLine("encerrando sessao de captura.");
            return 0;
        }
    }
}
