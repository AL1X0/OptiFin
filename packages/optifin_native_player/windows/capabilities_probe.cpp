#include "capabilities_probe.h"

#include <d3d11.h>
#include <dxgi1_6.h>
#include <initguid.h>
#include <windows.h>
#include <wrl/client.h>

#include <string>

#pragma comment(lib, "d3d11.lib")
#pragma comment(lib, "dxgi.lib")

namespace optifin {

namespace {

using Microsoft::WRL::ComPtr;
using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

// Profils de décodage D3D11 (d3d11.h ne les déclare pas tous selon le SDK).
DEFINE_GUID(kH264, 0x1b81be68, 0xa0c7, 0x11d3, 0xb9, 0x84, 0x00, 0xc0, 0x4f, 0x2e, 0x73, 0xc5);
DEFINE_GUID(kHevcMain, 0x5b11d51b, 0x2f4c, 0x4452, 0xbc, 0xc3, 0x09, 0xf2, 0xa1, 0x16, 0x0c, 0xc0);
DEFINE_GUID(kHevcMain10, 0x107af0e0, 0xef1a, 0x4d19, 0xab, 0xa8, 0x67, 0xa1, 0x63, 0x07, 0x3d, 0x13);
DEFINE_GUID(kVp9, 0x463707f8, 0xa1d0, 0x4585, 0x87, 0x6d, 0x83, 0xaa, 0x6d, 0x60, 0xb8, 0x9e);
DEFINE_GUID(kVp9Profile2, 0xa4c749ef, 0x6ecf, 0x48aa, 0x84, 0x48, 0x50, 0xa7, 0xa1, 0x16, 0x5f, 0xf7);
DEFINE_GUID(kAv1, 0xb8be4ccb, 0xcf53, 0x46ba, 0x8d, 0x59, 0xd6, 0xb8, 0xa6, 0xda, 0x5d, 0x2a);

std::string Utf8(const wchar_t* w) {
  const int n = WideCharToMultiByte(CP_UTF8, 0, w, -1, nullptr, 0, nullptr, nullptr);
  if (n <= 1) return {};
  std::string out(n - 1, '\0');
  WideCharToMultiByte(CP_UTF8, 0, w, -1, out.data(), n, nullptr, nullptr);
  return out;
}

// Le profil est-il décodable à cette résolution (et dans ce format de sortie) ?
bool Decodes(ID3D11VideoDevice* video, const GUID& profile, UINT width, UINT height, DXGI_FORMAT format) {
  BOOL supported = FALSE;
  if (FAILED(video->CheckVideoDecoderFormat(&profile, format, &supported)) || !supported) return false;
  D3D11_VIDEO_DECODER_DESC desc{profile, width, height, format};
  UINT configs = 0;
  return SUCCEEDED(video->GetVideoDecoderConfigCount(&desc, &configs)) && configs > 0;
}

// Un écran au moins est en mode HDR (Paramètres › Écran › « Utiliser le HDR »).
bool HdrDisplay(IDXGIAdapter1* adapter) {
  ComPtr<IDXGIOutput> output;
  for (UINT i = 0; adapter->EnumOutputs(i, &output) != DXGI_ERROR_NOT_FOUND; i++) {
    ComPtr<IDXGIOutput6> output6;
    DXGI_OUTPUT_DESC1 desc{};
    if (SUCCEEDED(output.As(&output6)) && SUCCEEDED(output6->GetDesc1(&desc)) &&
        desc.ColorSpace == DXGI_COLOR_SPACE_RGB_FULL_G2084_NONE_P2020) {
      return true;
    }
    output.Reset();
  }
  return false;
}

}  // namespace

EncodableMap ProbeCapabilities() {
  EncodableList video{EncodableValue("h264")};
  bool main10 = false;
  bool uhd = false;
  bool hdr = false;
  std::string model;

  ComPtr<IDXGIFactory1> factory;
  ComPtr<IDXGIAdapter1> adapter;
  if (SUCCEEDED(CreateDXGIFactory1(IID_PPV_ARGS(&factory))) && SUCCEEDED(factory->EnumAdapters1(0, &adapter))) {
    DXGI_ADAPTER_DESC1 desc{};
    adapter->GetDesc1(&desc);
    model = Utf8(desc.Description);
    hdr = HdrDisplay(adapter.Get());

    ComPtr<ID3D11Device> device;
    if (SUCCEEDED(D3D11CreateDevice(adapter.Get(), D3D_DRIVER_TYPE_UNKNOWN, nullptr, D3D11_CREATE_DEVICE_VIDEO_SUPPORT,
                                    nullptr, 0, D3D11_SDK_VERSION, &device, nullptr, nullptr))) {
      ComPtr<ID3D11VideoDevice> dev;
      if (SUCCEEDED(device.As(&dev))) {
        const bool hevc = Decodes(dev.Get(), kHevcMain, 1920, 1080, DXGI_FORMAT_NV12);
        main10 = Decodes(dev.Get(), kHevcMain10, 1920, 1080, DXGI_FORMAT_P010);
        if (hevc || main10) video.push_back(EncodableValue("hevc"));
        if (Decodes(dev.Get(), kVp9, 1920, 1080, DXGI_FORMAT_NV12) ||
            Decodes(dev.Get(), kVp9Profile2, 1920, 1080, DXGI_FORMAT_P010)) {
          video.push_back(EncodableValue("vp9"));
        }
        if (Decodes(dev.Get(), kAv1, 1920, 1080, DXGI_FORMAT_NV12)) video.push_back(EncodableValue("av1"));
        uhd = Decodes(dev.Get(), main10 ? kHevcMain10 : kHevcMain, 3840, 2160, main10 ? DXGI_FORMAT_P010 : DXGI_FORMAT_NV12) ||
              Decodes(dev.Get(), kH264, 3840, 2160, DXGI_FORMAT_NV12);
      }
    }
  }

  // HDR : mpv (gpu-next) envoie HDR10, HLG et Dolby Vision tels quels à un écran HDR, et les
  // convertit proprement en SDR sinon. Les gammes ne servent qu'au lecteur natif (absent ici).
  EncodableList ranges{EncodableValue("sdr")};
  if (hdr) {
    ranges.push_back(EncodableValue("hdr10"));
    ranges.push_back(EncodableValue("hlg"));
  }
  OSVERSIONINFOEXW os{sizeof(os)};
  using RtlGetVersion = LONG(WINAPI*)(OSVERSIONINFOEXW*);
  if (auto fn = reinterpret_cast<RtlGetVersion>(GetProcAddress(GetModuleHandleW(L"ntdll.dll"), "RtlGetVersion"))) {
    fn(&os);
  }
  return EncodableMap{
      {EncodableValue("platform"), EncodableValue("windows")},
      {EncodableValue("nativeAvailable"), EncodableValue(false)},
      {EncodableValue("model"), EncodableValue(model)},
      {EncodableValue("osVersion"), EncodableValue("Windows " + std::to_string(os.dwMajorVersion) + "." +
                                                   std::to_string(os.dwMinorVersion) + "." +
                                                   std::to_string(os.dwBuildNumber))},
      {EncodableValue("videoCodecs"), EncodableValue(video)},
      {EncodableValue("hevcMain10"), EncodableValue(main10)},
      {EncodableValue("ranges"), EncodableValue(ranges)},
      {EncodableValue("maxWidth"), EncodableValue(uhd ? 3840 : 1920)},
      {EncodableValue("pictureInPicture"), EncodableValue(false)},
      {EncodableValue("airPlay"), EncodableValue(false)},
      {EncodableValue("hdrDisplay"), EncodableValue(hdr)},
  };
}

}  // namespace optifin
