PRIMA File Reader for AviUtl
============================

これは PSDTool(https://oov.github.com/psdtool/) でシンプルビューを元にして出力できる PRIMA (Pre-Rendered IMage Archive) ファイルを AviUtl で読み込めるようにする AviUtl 用入力プラグインです。

注意事項
--------

PRIMA ファイルに関連するあらゆる仕組みは現在実験段階です。
予告なく仕様変更や開発中止が行われる可能性があります。

また、このプラグインを使用したこと及び使用しなかったことによるいかなる損害について、開発者は何も保証しません。  
これに同意できない場合、あなたはこのプラグインを使用することができません。

インストール
------------

prima.aui を[リリースページ](https://github.com/oov/aviutl_prima/releases)からダウンロードして、 aviutl.exe と同じ場所にコピーすればインストール完了です。

### 豆知識

もし拡張編集プラグインのウィンドウへのドラッグで読み込みたい場合は、exedit.ini をテキストエディタで開き「.prima=動画ファイル」の行を追加する必要があります。

※この変更をしなくてもウィンドウへのドラッグ＆ドロップ以外なら読み込めます。  
（例えば右クリックメニューから「メディアオブジェクトの追加」→「動画ファイル」で空の動画ファイルオブジェクトを追加して、参照ボタンでファイルを選ぶ場合など）

動作確認
--------

AviUtl 本体側で PRIMA ファイルを開いて、画像が表示されれば成功です。

ただし、AviUtl 側の「環境設定」→「システム設定」→「最大画像サイズ」の設定によって読み込める大きさが制限されている場合、そのサイズを超えるときは読み込みに失敗します。

必要に応じて制限を緩和してください。

PRIMA ファイルとは
------------------

PRIMA ファイルは似たパターンの静止画を詰め込んだ PSDTool 独自のファイル形式で、同じパターン数を PNG ファイルで用意すると合計ファイルサイズがギガバイト単位に至るような場合でも、PRIMA ファイルで格納すると数メガバイトにまで抑えられるケースもあります。

任意の表示パターンへのランダムアクセスにもそこそこ強く、それなりの常駐メモリとそこそこの速度で表示パターン切り替えが可能です。

上記の通り PRIMA ファイルは静止画の詰め合わせであり動画ではありませんが、このプラグインでは各表示パターンを1つのキーフレームとして扱うことにより PRIMA ファイルを 1fps の動画としてアクセスできるようにしています。

謝辞
----

This program uses the following library that ported for Free Pascal.

https://github.com/pierrec/lz4
```
Copyright (c) 2015, Pierre Curto
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.

* Neither the name of xxHash nor the names of its
  contributors may be used to endorse or promote products derived from
  this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```
