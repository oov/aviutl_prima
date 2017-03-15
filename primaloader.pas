unit PrimaLoader;

{$mode objfpc}{$H+}{$R-}
{$CODEPAGE UTF-8}

interface

uses
  Classes, SysUtils;

type
  PIntegerArray = ^TIntegerArray;
  TIntegerArray = array[0..$fffffff] of integer;

  PPixel = ^TPixel;

  TPixel = packed record
    C0: byte;
    C1: byte;
    C2: byte;
    C3: byte;
  end;

  PTiledImage = ^TTiledImage;

  TTiledImage = record
    P: PPixel;
    Width: integer;
    Height: integer;
    Columns: integer;
    TileCount: integer;
    TileTotal: integer;
  end;

  PTiledImageArray = ^TTiledImageArray;
  TTiledImageArray = array[0..$3ffffff] of TTiledImage;

  TPrimaRenderer = class;

  { TPrima }

  TPrima = class
  private
    FRenderer: TPrimaRenderer;
  public
    constructor Create();
    destructor Destroy(); override;
    procedure LoadFromStream(Stream: TStream);
    property Renderer: TPrimaRenderer read FRenderer;
  end;

  { TPrimaRenderer }

  TPrimaRenderer = class
  private
    FIndex: integer;
    FWidth: integer;
    FHeight: integer;
    FTileSize: integer;
    FImages: array of TTiledImage;
    FIdMapper: PIntegerArray;
    FIdMapperLen: integer;
    FBlockSize: integer;
    FBlocks: array of PByteArray;
    FTile: array of integer;
    FImage: PPixel;
    function GetLineSize: integer;
    function GetPatterns: integer;
    function GetTiledImage(i: integer): TTiledImage;
    function GetTiledImageCount: integer;
    procedure SetIndex(AValue: integer);
    procedure Render();
  public
    constructor Create(const Width: integer; const Height: integer;
      const TileSize: integer; const Images: array of TTiledImage;
      const IdMapper: PIntegerArray; const IdMapperLen: integer;
      const Blocks: array of PByteArray; const BlockSize: integer);
    destructor Destroy(); override;
    property Width: integer read FWidth;
    property Height: integer read FHeight;
    property TileSize: integer read FTileSize;
    property LineSize: integer read GetLineSize;
    property Index: integer read FIndex write SetIndex;
    property Patterns: integer read GetPatterns;
    property ImageBuffer: PPixel read FImage;
    property TiledImageCount: integer read GetTiledImageCount;
    property TiledImage[i: integer]: TTiledImage read GetTiledImage;
  end;

implementation

type
  TDNNAChunk = record
    Width: integer;
    Height: integer;
    TileSize: integer;
  end;

  TTile = record
    BlockSize: integer;
    Blocks: array of PByteArray;
  end;

  TIdMapper = record
    Len: integer;
    Map: PIntegerArray;
  end;

  TUnmanagedMemoryStream = class(TCustomMemoryStream)
  public
    constructor Create(const P: Pointer; Sz: PtrInt);
    destructor Destroy; override;
  end;

{ TUnmanagedMemoryStream }

constructor TUnmanagedMemoryStream.Create(const P: Pointer; Sz: PtrInt);
begin
  inherited Create;
  SetPointer(P, Sz);
end;

destructor TUnmanagedMemoryStream.Destroy;
begin
  inherited Destroy;
end;

(**
 * Copyright (c) 2015, Pierre Curto
 * Copyright (c) 2016, oov
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * * Redistributions of source code must retain the above copyright notice, this
 *   list of conditions and the following disclaimer.
 *
 * * Redistributions in binary form must reproduce the above copyright notice,
 *   this list of conditions and the following disclaimer in the documentation
 *   and/or other materials provided with the distribution.
 *
 * * Neither the name of xxHash nor the names of its
 *   contributors may be used to endorse or promote products derived from
 *   this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *)
function uncompress(const Src: TStream; const SrcLen: integer; var Dest;
  const DestLen: integer): integer;
var
  D: TByteArray absolute Dest;
  b, b2: byte;
  SI, DI, Offset: integer;
  LLen, MLen: integer;
begin
  if SrcLen = 0 then
  begin
    Result := 0;
    Exit;
  end;

  SI := 0;
  DI := 0;
  while True do
  begin
    // literals and match lengths (token)
    b := Src.ReadByte();
    Inc(SI);
    LLen := b shr 4;
    MLen := b and $0f;
    if SI = SrcLen then
      raise Exception.Create('invalid source');

    // literals
    if LLen > 0 then
    begin
      if LLen = $0f then
      begin
        b := Src.ReadByte();
        Inc(SI);
        while b = $ff do
        begin
          Inc(LLen, b);
          if SI = SrcLen then
            raise Exception.Create('invalid source');
          b := Src.ReadByte();
          Inc(SI);
        end;
        Inc(LLen, b);
        if SI = SrcLen then
          raise Exception.Create('invalid source');
      end;
      if (DestLen - DI < LLen) or (SI + LLen > SrcLen) then
        raise Exception.Create('short buffer');
      Src.ReadBuffer(D[DI], LLen);
      Inc(DI, LLen);
      Inc(SI, LLen);
      if SI >= SrcLen then
      begin
        Result := DI;
        Exit;
      end;
    end;

    Inc(SI, 2);
    if SI >= SrcLen then
      raise Exception.Create('invalid source');
    b := Src.ReadByte();
    b2 := Src.ReadByte();
    Offset := b or (b2 shl 8);
    if (DI - Offset < 0) or (Offset = 0) then
      raise Exception.Create('invalid source');

    // match
    if MLen = $0f then
    begin
      b := Src.ReadByte();
      Inc(SI);
      while b = $ff do
      begin
        Inc(MLen, $ff);
        if SI = SrcLen then
          raise Exception.Create('invalid source');
        b := Src.ReadByte();
        Inc(SI);
      end;
      Inc(MLen, b);
      if SI = SrcLen then
        raise Exception.Create('invalid source');
    end;

    // minimum match length is 4
    Inc(MLen, 4);
    if DestLen - DI <= MLen then
      raise Exception.Create('short buffer');

    // copy the match (NB. match is at least 4 bytes long)
    while MLen >= Offset do
    begin
      Move(D[DI - Offset], D[DI], Offset);
      Inc(DI, Offset);
      Dec(MLen, Offset);
    end;
    Move(D[DI - Offset], D[DI], MLen);
    Inc(DI, MLen);
  end;
end;

function readLZ4Stream(const Stream: TStream; const DestLen: cardinal): Pointer;
var
  BlockSize, Pos, Len, Written: cardinal;
  Compressed: boolean;
  Header: array[0..2] of byte;
  Buf, P: PByteArray;
begin
  if LEtoN(Stream.ReadDWord()) <> $184d2204 then
    raise Exception.Create('unexpected file signature');
  Header[0] := 0;
  Stream.ReadBuffer(Header, 3);
  if (Header[0] = $60) and (Header[1] = $60) and (Header[2] = $51) then
    BlockSize := 1024 * 1024
  else if (Header[0] = $60) and (Header[1] = $70) and (Header[2] = $73) then
    BlockSize := 4 * 1024 * 1024
  else
    raise Exception.Create('unexpected frame descriptor');
  Pos := 0;
  P := GetMem(DestLen);
  try
    while Pos < DestLen do
    begin
      Len := LEtoN(Stream.ReadDword());
      Compressed := (Len and $80000000) = 0;
      Len := Len and $7fffffff;
      if Pos + BlockSize <= DestLen then
      begin
        if Compressed then
        begin
          Written := uncompress(Stream, Len, P^[Pos], BlockSize);
          Inc(Pos, Written);
        end
        else
        begin
          Stream.ReadBuffer(P^[Pos], Len);
          Inc(Pos, Len);
        end;
      end
      else
      begin
        if Compressed then
        begin
          Buf := GetMem(BlockSize);
          try
            Written := uncompress(Stream, Len, Buf^, BlockSize);
            Move(Buf^, P^[Pos], DestLen - Pos);
          finally
            FreeMem(Buf);
          end;
        end
        else
        begin
          Stream.ReadBuffer(P^[Pos], DestLen - Pos);
        end;
        Pos := DestLen;
      end;
    end;
  except
    FreeMem(P);
    raise;
  end;
  Result := P;
end;

function readDNNA(const Stream: TStream; const Len: cardinal): TDNNAChunk;
begin
  if Len < 10 then
    raise Exception.Create('file is corrupted');
  Result.Width := LEtoN(Stream.ReadDword());
  Result.Height := LEtoN(Stream.ReadDword());
  Result.TileSize := LEtoN(Stream.ReadWord());
end;

function readImage(const Stream: TStream; const Len: cardinal): TTiledImage;
var
  I: integer;
  P: PPixel;
  D: TPixel;
begin
  if Len < 8 then
    raise Exception.Create('file is corrupted');
  Result.Width := LEtoN(Stream.ReadDword());
  Result.Height := LEtoN(Stream.ReadDword());
  P := readLZ4Stream(Stream, Result.Width * Result.Height * SizeOf(TPixel));
  Result.P := P;
  D.C0 := 0;
  D.C1 := 0;
  D.C2 := 0;
  D.C3 := 0;
  for I := 0 to Result.Width * Result.Height - 1 do
  begin
    Inc(P^.C0, D.C0);
    Inc(P^.C1, D.C1);
    Inc(P^.C2, D.C2);
    Inc(P^.C3, D.C3);
    D.C0 := P^.C0;
    D.C1 := P^.C1;
    D.C2 := P^.C2;
    D.C3 := P^.C3;
    Inc(P);
  end;
end;

function readIdMapper(const Stream: TStream; const Len: cardinal): TIdMapper;
var
  I: integer;
  P: PIntegerArray;
begin
  if Len < 4 then
    raise Exception.Create('file is corrupted');
  Result.Len := Len shr 2;
  Result.Map := GetMem(Len);
  try
    Stream.ReadBuffer(Result.Map^, Len);
    P := Result.Map;
    for I := 0 to Result.Len - 1 do
    begin
      P^[I] := LEtoN(P^[I]);
    end;
  except
    FreeMem(Result.Map);
    raise;
  end;
end;

function readTile(const Stream: TStream; const Len: cardinal): TTile;
var
  Header: array[0..2] of byte;
  P: PByteArray;
  Pos, DestLen, L: cardinal;
  MS: TUnmanagedMemoryStream;
begin
  if Len < 4 then
    raise Exception.Create('file is corrupted');
  DestLen := LEtoN(Stream.ReadDword());
  P := readLZ4Stream(Stream, DestLen);
  try
    MS := TUnmanagedMemoryStream.Create(P, DestLen);
    try
      if LEtoN(MS.ReadDWord()) <> $184d2204 then
        raise Exception.Create('unexpected file signature');
      Header[0] := 0;
      MS.ReadBuffer(Header, 3);
      if (Header[0] = $60) and (Header[1] = $60) and (Header[2] = $51) then
        Result.BlockSize := 1024 * 1024
      else if (Header[0] = $60) and (Header[1] = $70) and (Header[2] = $73) then
        Result.BlockSize := 4 * 1024 * 1024
      else
        raise Exception.Create('unexpected frame descriptor');

      Pos := 7;
      SetLength(Result.Blocks, 0);
      while Pos < DestLen do
      begin
        SetLength(Result.Blocks, Length(Result.Blocks) + 1);
        Result.Blocks[Length(Result.Blocks) - 1] := @P^[Pos];
        L := LEtoN(MS.ReadDword());
        Inc(Pos, 4);
        MS.Seek(L, soCurrent);
        Inc(Pos, L);
      end;
    finally
      MS.Free;
    end;
  except
    FreeMem(P);
    raise;
  end;
end;

function IntMin(A: integer; B: integer): integer;
begin
  if A > B then
    Result := B
  else
    Result := A;
end;

{ TPrima }

constructor TPrima.Create;
begin
  inherited Create();
end;

destructor TPrima.Destroy;
begin
  FreeAndNil(FRenderer);
  inherited Destroy;
end;

procedure TPrima.LoadFromStream(Stream: TStream);
var
  I: integer;
  Pos, StreamLen, Signature, Len: cardinal;
  MS: TMemoryStream;
  DNNA: TDNNAChunk;
  Images: array of TTiledImage;
  IdMapper: TIdMapper;
  TI: TTiledImage;
  T: TTile;
  Image: PPixel;
  NewRenderer: TPrimaRenderer;
begin
  Pos := 0;
  if LEtoN(Stream.ReadDWord()) <> $46464952 then // 'RIFF'
    raise Exception.Create('unexpected file signature');
  Inc(Pos, 4);

  StreamLen := LEtoN(Stream.ReadDword()) + 8;
  Inc(Pos, 4);
  NewRenderer := nil;
  Image := nil;
  IdMapper.Map := nil;
  T.Blocks := nil;
  try
    while Pos < StreamLen do
    begin
      Signature := LEtoN(Stream.ReadDWord());
      Inc(Pos, 4);
      Len := LEtoN(Stream.ReadDword());
      Inc(Pos, 4);
      MS := TMemoryStream.Create();
      try
        MS.Size := Len;
        MS.CopyFrom(Stream, MS.Size);
        MS.Position := 0;
        case Signature of
          $414e4e44:
          begin // 'DNNA'
            if Pos <> 16 then
              raise Exception.Create('unexpected file signature');
            DNNA := readDNNA(MS, Len);
          end;
          $184d2a50:
          begin // 'PTRN'
            // pPattern = readJSON(ab, pos, l);
          end;
          $20474d49:
          begin // 'IMG '
            TI := readImage(MS, Len);
            SetLength(Images, Length(Images) + 1);
            Images[Length(Images) - 1] := TI;
          end;
          $504d4449:
          begin // 'IDMP'
            IdMapper := readIdMapper(MS, Len);
          end;
          $454c4954:
          begin // 'TILE'
            T := readTile(MS, Len);
          end;
        end;
      finally
        MS.Free;
      end;
      Inc(Pos, Len);
    end;
    NewRenderer := TPrimaRenderer.Create(DNNA.Width, DNNA.Height,
      DNNA.TileSize, Images, IdMapper.Map, IdMapper.Len, T.Blocks, T.BlockSize);
    FreeAndNil(FRenderer);
    FRenderer := NewRenderer;
    NewRenderer := nil;
  except
    if Assigned(NewRenderer) then
      FreeMem(NewRenderer);
    if Assigned(Image) then
      FreeMem(Image);
    for I := 0 to Length(Images) - 1 do
    begin
      if Assigned(Images[i].P) then
        FreeMem(Images[i].P);
    end;
    if Assigned(IdMapper.Map) then
      FreeMem(IdMapper.Map);
    if (Length(T.Blocks) > 0) and Assigned(T.Blocks[0]) then
      FreeMem(@T.Blocks[0][-7]);
    raise;
  end;
end;

{ TPrimaRenderer }

procedure TPrimaRenderer.SetIndex(AValue: integer);
var
  Origin: int64;
  I, TW, TH, TileSetLen, BlockSize, BlocksLen, BlockIndex, BlockOrigin, Pos: integer;
  Idx, Len: integer;
  BlockBuf, P: PIntegerArray;
  Src: PByteArray;
  MS: TUnmanagedMemoryStream;
begin
  if FIndex = AValue then
    Exit;
  if (AValue < 0) or (AValue >= FIdMapperLen) then
    raise Exception.Create('out of index');

  Idx := FIdMapper^[AValue];

  TW := (FWidth + FTileSize - 1) div FTileSize;
  TH := (FHeight + FTileSize - 1) div FTileSize;
  TileSetLen := TW * TH;
  P := @FTile[TileSetLen];

  Origin := int64(Idx) * TileSetLen * SizeOf(integer);
  BlockSize := FBlockSize;
  BlockIndex := integer(Origin div int64(BlockSize));
  BlockOrigin := integer(Origin - int64(BlockIndex) * BlockSize) shr 2;
  BlocksLen := Length(FBlocks);

  BlockBuf := GetMem(BlockSize);
  try
    Pos := 0;
    while (Pos < TileSetLen) and (BlockIndex < BlocksLen) do
    begin
      Len := LEtoN(PInteger(FBlocks[BlockIndex])^);
      Src := @FBlocks[BlockIndex]^[SizeOf(integer)];
      if (Len and $80000000) = 0 then
      begin
        MS := TUnmanagedMemoryStream.Create(Src, Len);
        try
          Len := uncompress(MS, Len, BlockBuf^, BlockSize);
        finally
          MS.Free;
        end;
        for I := BlockOrigin to BlockOrigin + IntMin(
            (Len shr 2) - BlockOrigin, TileSetLen - Pos) - 1 do
        begin
          P^[Pos] := LEtoN(BlockBuf^[I]);
          Inc(Pos);
        end;
      end
      else
      begin
        Len := Len and $7fffffff;
        for I := 0 to IntMin(Len shr 2, TileSetLen - Pos) do
        begin
          P^[Pos] := LEtoN(BlockBuf^[I]);
          Inc(Pos);
        end;
      end;
      Inc(BlockIndex);
      BlockOrigin := 0;
    end;
  finally
    FreeMem(BlockBuf);
  end;
  Render();
  FIndex := AValue;
end;

function TPrimaRenderer.GetLineSize: integer;
begin
  Result := ((FWidth + FTileSize - 1) div FTileSize) * FTileSize;
end;

function TPrimaRenderer.GetPatterns: integer;
begin
  Result := FIdMapperLen;
end;

function TPrimaRenderer.GetTiledImage(i: integer): TTiledImage;
begin
  Result := FImages[i];
end;

function TPrimaRenderer.GetTiledImageCount: integer;
begin
  Result := Length(FImages);
end;

function findImage(Images: PTiledImageArray; ImagesLen: integer;
  Id: integer): integer; inline;
var
  I: integer;
begin
  for I := 0 to ImagesLen - 1 do
  begin
    if Id < Images^[I].TileTotal then
    begin
      Result := I;
      Exit;
    end;
  end;
  Result := -1;
end;

procedure TPrimaRenderer.Render;
var
  I, J, TW, TH, DW, DLine, DX, DY, SLine, SX, SY, TileSetLen, TileIndex: integer;
  TileSizeLen, ImageIndex, ImagesLen: integer;
  P, NextP: PIntegerArray;
  DPix, DPixStart, SPix: PPixel;
  Images: PTiledImageArray;
  Image: PTiledImage;
begin
  Images := @FImages[0];
  ImagesLen := Length(FImages);
  TileSizeLen := FTileSize;
  TW := (FWidth + TileSizeLen - 1) div TileSizeLen;
  TH := (FHeight + TileSizeLen - 1) div TileSizeLen;
  TileSetLen := TW * TH;
  P := @FTile[0];
  NextP := @FTile[TileSetLen];
  DW := TW;
  DLine := TW * TileSizeLen;
  DPixStart := FImage;
  DX := 0;
  DY := 0;
  for I := 0 to TileSetLen - 1 do
  begin
    if P^[I] <> NextP^[I] then
    begin
      ImageIndex := findImage(Images, ImagesLen, NextP^[I] - 1);
      if ImageIndex = -1 then
        raise Exception.Create('invalid index');
      Image := @Images^[ImageIndex];
      TileIndex := NextP^[I] - Image^.TileTotal + Image^.TileCount - 1;
      if TileIndex = -1 then
        raise Exception.Create('invalid index');
      SPix := Image^.P;
      SLine := Image^.Width;
      SY := TileIndex div Image^.Columns;
      SX := TileIndex - SY * Image^.Columns;
      Inc(SPix, SY * SLine * TileSizeLen + SX * TileSizeLen);

      DPix := DPixStart;
      Inc(DPix, DY * DLine * TileSizeLen + DX * TileSizeLen);
      for J := 0 to TileSizeLen - 1 do
      begin
        Move(SPix^, DPix^, SizeOf(TPixel) * TileSizeLen);
        Inc(SPix, SLine);
        Inc(DPix, DLine);
      end;

      P^[I] := NextP^[I];
    end;

    Inc(DX);
    if DX = DW then
    begin
      Inc(DY);
      DX := 0;
    end;
  end;
end;

constructor TPrimaRenderer.Create(const Width: integer; const Height: integer;
  const TileSize: integer; const Images: array of TTiledImage;
  const IdMapper: PIntegerArray; const IdMapperLen: integer;
  const Blocks: array of PByteArray; const BlockSize: integer);
var
  I, N, TW, TH: integer;
begin
  inherited Create();
  FWidth := Width;
  FHeight := Height;
  FTileSize := TileSize;

  N := 0;
  SetLength(FImages, Length(Images));
  for I := 0 to Length(FImages) - 1 do
  begin
    FImages[I] := Images[I];
    TW := FImages[I].Width div TileSize;
    TH := FImages[I].Height div TileSize;
    FImages[I].Columns := TW;
    FImages[I].TileCount := TW * TH;
    Inc(N, FImages[I].TileCount);
    FImages[I].TileTotal := N;
  end;

  FIdMapper := IdMapper;
  FIdMapperLen := IdMapperLen;

  SetLength(FBlocks, Length(Blocks));
  for I := 0 to Length(FBlocks) - 1 do
  begin
    FBlocks[I] := Blocks[I];
  end;
  FBlockSize := BlockSize;

  TW := (Width + TileSize - 1) div TileSize;
  TH := (Height + TileSize - 1) div TileSize;
  SetLength(FTile, TW * TH * 2);
  FImage := GetMem((TW * TileSize) * (TH * TileSize) * SizeOf(TPixel));

  FIndex := -1;
  Index := 0;
end;

destructor TPrimaRenderer.Destroy;
var
  I: integer;
  P: PByte;
begin
  if Assigned(FImage) then
    FreeMem(FImage);
  if (Length(FBlocks) > 0) and Assigned(FBlocks[0]) then
  begin
    P := Pointer(FBlocks[0]);
    Dec(P, 7);
    FreeMem(P);
  end;
  if Assigned(FIdMapper) then
    FreeMem(FIdMapper);
  for I := 0 to Length(FImages) - 1 do
    if Assigned(FImages[I].P) then
      FreeMem(FImages[I].P);
  inherited Destroy;
end;

end.


