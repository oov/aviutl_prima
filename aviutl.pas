unit AviUtl;

{$mode objfpc}{$H+}
{$CODEPAGE UTF-8}

interface

uses
  Windows;

const
  AVIUTL_TRUE = 1; // -1 is not True in AviUtl world
  AVIUTL_FALSE = 0;

  INPUT_INFO_FLAG_VIDEO = 1;
  INPUT_INFO_FLAG_AUDIO = 2;
  INPUT_INFO_FLAG_VIDEO_RANDOM_ACCESS = 8;

  INPUT_PLUGIN_FLAG_VIDEO = 1;
  INPUT_PLUGIN_FLAG_AUDIO = 2;

type
  AviUtlBool = integer;

  PInputInfo = ^TInputInfo;

  TInputInfo = record
    Flag: integer;
    Rate: integer;
    Scale: integer;
    N: integer;
    Format: PBitmapInfoHeader;
    FormatSize: integer;
    AudioN: integer;
    AudioFormat: PWaveFormatEx;
    AudioFormatSize: integer;
    Handler: cardinal;
    Reserved: array[0..6] of integer;
  end;

  // BOOL    (*func_init)( void );
  TInitFunc = function(): AviUtlBool; cdecl;

  // BOOL    (*func_exit)( void );
  TExitFunc = function(): AviUtlBool; cdecl;

  // INPUT_HANDLE (*func_open)( LPSTR file );
  TOpenFunc = function(FileName: PChar): Pointer; cdecl;

  // BOOL (*func_close)( INPUT_HANDLE ih );
  TCloseFunc = function(H: Pointer): AviUtlBool; cdecl;

  // BOOL (*func_info_get)( INPUT_HANDLE ih, INPUT_INFO *iip );
  TInfoGetFunc = function(H: Pointer; II: PInputInfo): AviUtlBool; cdecl;

  // int (*func_read_video)( INPUT_HANDLE ih, int frame, void *buf );
  TReadVideoFunc = function(H: Pointer; Frame: integer; Buffer: Pointer): integer; cdecl;

  // int (*func_read_audio)( INPUT_HANDLE ih, int start, int length, void *buf );
  TReadAudioFunc = function(H: Pointer; Start: integer; Len: integer;
    Buffer: Pointer): integer; cdecl;

  // BOOL (*func_is_keyframe)( INPUT_HANDLE ih, int frame );
  TIsKeyframeFunc = function(H: Pointer; Frame: integer): AviUtlBool; cdecl;

  // BOOL (*func_config)( HWND hwnd, HINSTANCE dll_hinst );
  TConfigFunc = function(Hwnd: THandle; hinstance: THandle): AviUtlBool; cdecl;

  PInputPluginTable = ^TInputPluginTable;

  TInputPluginTable = record
    Flag: integer;
    Name: PChar;
    FileFilter: PChar;
    Information: PChar;
    FuncInit: TInitFunc;
    FuncExit: TExitFunc;
    FuncOpen: TOpenFunc;
    FuncClose: TCloseFunc;
    FuncInfoGet: TInfoGetFunc;
    FuncReadVideo: TReadVideoFunc;
    FuncReadAudio: TReadAudioFunc;
    FuncIsKeyFrame: TIsKeyFrameFunc;
    FuncConfig: TConfigFunc;
    Reserved: array[0..15] of integer;
  end;

implementation

end.
