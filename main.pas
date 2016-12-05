unit Main;

{$mode objfpc}{$H+}
{$CODEPAGE UTF-8}

interface

uses
  Windows, Classes, aviutl, PrimaLoader;

function GetInputPluginTable(): PInputPluginTable; stdcall;

implementation

type

  { TPrimaFile }

  TPrimaFile = class
  private
    FBIH: TBitmapInfoHeader;
    FPrima: TPrima;
  public
    constructor Create(const P: TPrima);
    destructor Destroy(); override;
    property Prima: TPrima read FPrima;
    property BIH: TBitmapInfoHeader read FBIH;
  end;

function Open(FileName: PChar): Pointer; cdecl;
var
  P: TPrima;
  FS: TFileStream;
begin
  P := TPrima.Create();
  try
    FS := TFileStream.Create(FileName, fmOpenRead);
    try
      P.LoadFromStream(FS);
    finally
      FS.Free;
    end;
    Result := TPrimaFile.Create(P);
  except
    P.Free;
    Result := nil;
  end;
end;

function Close(H: Pointer): AviUtlBool; cdecl;
var
  PF: TPrimaFile absolute H;
begin
  if Assigned(PF) then
    PF.Free;
  Result := AVIUTL_TRUE;
end;

function InfoGet(H: Pointer; II: PInputInfo): AviUtlBool; cdecl;
var
  PF: TPrimaFile absolute H;
begin
  II^.Flag := INPUT_INFO_FLAG_VIDEO or INPUT_INFO_FLAG_VIDEO_RANDOM_ACCESS;
  II^.Rate := 1;
  II^.Scale := 1;
  II^.N := PF.Prima.Renderer.Patterns;
  II^.Format := @PF.BIH;
  II^.FormatSize := PF.BIH.biSize;
  II^.AudioN := 0;
  II^.AudioFormat := nil;
  II^.AudioFormatSize := 0;
  II^.Handler := 0;
  Result := AVIUTL_TRUE;
end;

function ReadVideo(HFile: Pointer; Frame: integer; Buffer: Pointer): integer; cdecl;
var
  PF: TPrimaFile absolute HFile;
  P: TPrima;
  X, Y, DLine, SLine, W, H: integer;
  DPix, SPix, DPixStart, SPixStart: PPixel;
begin
  P := PF.Prima;
  if (0 <= Frame) and (Frame < P.Renderer.Patterns) then
    P.Renderer.Index := Frame;

  W := P.Renderer.Width;
  H := P.Renderer.Height;
  SPixStart := P.Renderer.ImageBuffer;
  SLine := P.Renderer.LineSize;
  DPixStart := Buffer;
  DLine := W;

  for Y := 0 to H - 1 do
  begin
    SPix := SPixStart;
    Inc(SPix, Y * SLine);
    DPix := DPixStart;
    Inc(DPix, (H - Y - 1) * DLine);
    for X := 0 to W - 1 do
    begin
      DPix^.C0 := SPix^.C2;
      DPix^.C1 := SPix^.C1;
      DPix^.C2 := SPix^.C0;
      DPix^.C3 := SPix^.C3;
      Inc(DPix);
      Inc(SPix);
    end;
  end;
  Result := (W shl 2) * H;
end;

function ReadAudio(H: Pointer; Start: integer; Len: integer;
  Buffer: Pointer): integer; cdecl;
begin
  Result := 0;
end;

constructor TPrimaFile.Create(const P: TPrima);
begin
  inherited Create();
  FPrima := P;
  FillChar(FBIH, SizeOf(TBitmapInfoHeader), 0);
  FBIH.biSize := SizeOf(TBitmapInfoHeader);
  FBIH.biWidth := P.Renderer.Width;
  FBIH.biHeight := P.Renderer.Height;
  FBIH.biPlanes := 1;
  FBIH.biBitCount := 32;
  FBIH.biCompression := BI_RGB;
end;

destructor TPrimaFile.Destroy;
begin
  if Assigned(FPrima) then
    FPrima.Free;
  inherited Destroy;
end;


function GetInputPluginTable(): PInputPluginTable; stdcall;
const
  InputPluginTable: TInputPluginTable = (
    Flag: INPUT_PLUGIN_FLAG_VIDEO;
    Name: 'PRIMA File Reader';
    FileFilter: 'PRIMA File(*.prima)'#0'*.prima'#0;
    Information: 'PRIMA File Reader v0.1 By oov';
    FuncInit: nil;
    FuncExit: nil;
    FuncOpen: @Open;
    FuncClose: @Close;
    FuncInfoGet: @InfoGet;
    FuncReadVideo: @ReadVideo;
    FuncReadAudio: @ReadAudio;
    FuncIsKeyFrame: nil;
    FuncConfig: nil;
    Reserved: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    );
begin
  Result := @InputPluginTable;
end;

end.
