// Copyright (c) 2010-2026 Zhang Weidong <zwd@funlang.org>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
unit ie;

interface

uses Windows, ActiveX, KOL, KOLSHDocVw;

type

PDOCHOSTUIINFO = ^TDOCHOSTUIINFO;
  TDOCHOSTUIINFO = record
    cbSize: ULONG;
    dwFlags: DWORD;
    dwDoubleClick: DWORD;
    chHostCss: Pointer;
    chHostNS: Pointer;
  end;
  
  // Dont Change the Order !!!
  IDocHostUIHandler = interface(IInterface)
    ['{bd3f23c0-d43e-11cf-893b-00aa00bdce1a}']
    function ShowContextMenu(const dwID: DWORD; const ppt: PPOINT; const pcmdtReserved: IUnknown; const pdispReserved: IDispatch): HRESULT; stdcall;
    function GetHostInfo(var pInfo: TDOCHOSTUIINFO): HRESULT; stdcall;
    function ShowUI(const dwID: DWORD; const pActiveObject: IOleInPlaceActiveObject; const pCommandTarget: IOleCommandTarget; const pFrame: IOleInPlaceFrame;
            const pDoc: IOleInPlaceUIWindow): HRESULT; stdcall;
    function HideUI: HRESULT; stdcall;
    function UpdateUI: HRESULT; stdcall;
    function EnableModeless(const fEnable: BOOL): HRESULT; stdcall;
    function OnDocWindowActivate(const fActivate: BOOL): HRESULT; stdcall;
    function OnFrameWindowActivate(const fActivate: BOOL): HRESULT; stdcall;
    function ResizeBorder(const prcBorder: PRECT; const pUIWindow: IOleInPlaceUIWindow; const fRameWindow: BOOL): HRESULT; stdcall;
    function TranslateAccelerator(const lpMsg: PMSG; const pguidCmdGroup: PGUID; const nCmdID: DWORD): HRESULT; stdcall;
    function GetOptionKeyPath(var pchKey: POLESTR; const dw: DWORD): HRESULT; stdcall;
    function GetDropTarget(const pDropTarget: IDropTarget; out ppDropTarget: IDropTarget): HRESULT; stdcall;
    function GetExternal(out ppDispatch: IDispatch): HRESULT; stdcall;
    function TranslateUrl(const dwTranslate: DWORD; const pchURLIn: POLESTR; var ppchURLOut: POLESTR): HRESULT; stdcall;
    function FilterDataObject(const pDO: IDataObject; out ppDORet: IDataObject): HRESULT; stdcall;
  end;
  
  ICustomDoc = interface(IUnknown)
    ['{3050F3F0-98B5-11CF-BB82-00AA00BDCE0B}']
    function SetUIHandler(const pUIHandler: IDocHostUIHandler): HRESULT; stdcall;
  end;
  
  PKOLWebBrowser = ^TKOLWebBrowser;
  TKOLWebBrowser = object(TWebBrowser)
  private
    ieWndHooked: Boolean;
    handler: IDocHostUIHandler;
  protected
    procedure Init; virtual;
    procedure DocComplete(Sender: TObject; const pDisp: IDispatch; var URL: OleVariant);
    procedure DoComplete;
  public
    function WndProc( var Msg: TMsg ): Integer; virtual;
  end;

  TDocHostUIHandler = class(TInterfacedObject, IDocHostUIHandler)
  private
    web: TKOLWebBrowser;
  protected
    function EnableModeless(const fEnable: BOOL): HRESULT; stdcall;
    function FilterDataObject(const pDO: IDataObject; out ppDORet: IDataObject): HRESULT; stdcall;
    function GetDropTarget(const pDropTarget: IDropTarget; out ppDropTarget: IDropTarget): HRESULT; stdcall;
    function GetExternal(out ppDispatch: IDispatch): HRESULT; stdcall;
    function GetHostInfo(var pInfo: TDOCHOSTUIINFO): HRESULT; stdcall;
    function GetOptionKeyPath(var pchKey: POLESTR; const dw: DWORD): HRESULT; stdcall;
    function HideUI: HRESULT; stdcall;
    function OnDocWindowActivate(const fActivate: BOOL): HRESULT; stdcall;
    function OnFrameWindowActivate(const fActivate: BOOL): HRESULT; stdcall;
    function ResizeBorder(const prcBorder: PRECT; const pUIWindow: IOleInPlaceUIWindow; const fRameWindow: BOOL): HRESULT; stdcall;
    function ShowContextMenu(const dwID: DWORD; const ppt: PPOINT; const pcmdtReserved: IUnknown; const pdispReserved: IDispatch): HRESULT; stdcall;
    function ShowUI(const dwID: DWORD; const pActiveObject: IOleInPlaceActiveObject; const pCommandTarget: IOleCommandTarget; const pFrame: IOleInPlaceFrame;
            const pDoc: IOleInPlaceUIWindow): HRESULT; stdcall;
    function TranslateAccelerator(const lpMsg: PMSG; const pguidCmdGroup: PGUID; const nCmdID: DWORD): HRESULT; stdcall;
    function TranslateUrl(const dwTranslate: DWORD; const pchURLIn: POLESTR; var ppchURLOut: POLESTR): HRESULT; stdcall;
    function UpdateUI: HRESULT; stdcall;
  end;
  
function NewKOLWebBrowser(AOwner: PControl): PKOLWebBrowser;

implementation

uses Messages;

function NewKOLWebBrowser;
begin
  New(Result,CreateParented(AOwner));
end;

const WM_Start = WM_APP;
var
  OldWndFunc: Pointer = nil;
  OldWndFun2: Pointer = nil;

function TheWndFunc( W: HWnd; Msg: Cardinal; wParam, lParam: Integer; h: HWnd; Func: Pointer ): Integer; stdcall;
label
  Ex;
begin
  Result := 0;
  if h <> 0 then
  case Msg of
    WM_KEYDOWN, WM_KEYUP, WM_SYSKEYDOWN, WM_SYSKEYUP:
    begin
      case Msg of
        WM_KEYDOWN, WM_SYSKEYDOWN:
          case wParam of
            VK_F10: // F10
            begin
              Msg := WM_KEYDOWN;
              wParam := 0;
              goto Ex;
            end;

            VK_F5, VK_F6, VK_Menu: // F5, Ctrl-F5, F6, Alt
              goto Ex;

            Ord('F'), Ord('N'), Ord('P'), Ord('O'), Ord('L'): // Ctrl-F, Ctrl-N, Ctrl-P, Ctrl-O, Ctrl-L
              if GetKeyState(VK_Control) and $8000 = $8000 then goto Ex;
          end;
          
        WM_SYSKEYUP:
          if wParam = VK_F10 then Msg := WM_KEYUP;
      end;
      // Forward Messages
      if SendMessage(h, Msg + WM_Start, wParam, lParam) = WM_Start then Exit;
    end;
  end;
Ex:
  Result := CallWindowProc(Func, W, Msg, wParam, lParam);
end;

function WndFun2( W: HWnd; Msg: Cardinal; wParam, lParam: Integer ): Integer; stdcall;
begin
  // Internet Explorer_Server -> Shell Embedding
  Result := TheWndFunc(W, Msg, wParam, lParam, GetParent(GetParent(W)), OldWndFun2);
end;

function WndFunc( W: HWnd; Msg: Cardinal; wParam, lParam: Integer ): Integer; stdcall;
begin
  // Shell DocObject View     -> Shell Embedding
  Result := TheWndFunc(W, Msg, wParam, lParam,           GetParent(W),  OldWndFunc);
end;

function TKOLWebBrowser.WndProc( var Msg: TMsg ): Integer;
var
  h: THandle;
  r: Integer;
begin
  // Hook WndProc
  if not ieWndHooked then begin
    h := Handle;
    if h <> 0 then begin // Shell Embedding
      h := GetWindow(h, GW_CHILD);
      if h <> 0 then begin // Shell DocObject View
        if OldWndFunc = nil then
        begin
          OldWndFunc  := Pointer(GetWindowLong(h, GWL_WNDPROC));
                              SetWindowLong(h, GWL_WNDPROC, Longint(@WndFunc));
        end;
        h := GetWindow(h, GW_CHILD);
        if h <> 0 then begin // Internet Explorer_Server
          if OldWndFun2 = nil then
          begin
            OldWndFun2  := Pointer(GetWindowLong(h, GWL_WNDPROC));
            ieWndHooked := 0 <> SetWindowLong(h, GWL_WNDPROC, Longint(@WndFun2));
          end;
        end;
      end;
    end;
  end;

  if (Msg.message = WM_Start + WM_KEYDOWN) or
     (Msg.message = WM_Start + WM_KEYUP) or
     (Msg.message = WM_Start + WM_SYSKEYDOWN) or
     (Msg.message = WM_Start + WM_SYSKEYUP) then
  begin
    if FOleInPlaceActiveObject <> nil then
    begin
      Dec(Msg.message, WM_Start);
      r := FOleInPlaceActiveObject.TranslateAccelerator(Msg);
      Inc(Msg.message, WM_Start);
      if r = S_OK then
      begin
        Result := WM_Start;
        Exit;
      end;
    end;
    Result := 0;
    Exit;
  end;
  Result := inherited WndProc(Msg);
end;

procedure TKOLWebBrowser.Init;
var
  host: TDocHostUIHandler;
begin
  inherited;
  host := TDocHostUIHandler.Create();
  host.web := self;
  handler := host;
  OnNavigateComplete2 := DocComplete;
  //OnDocumentComplete := DocComplete;
end;

procedure TKOLWebBrowser.DocComplete(Sender: TObject; const pDisp: IDispatch; var URL: OleVariant);
begin
  DoComplete;
end;

procedure TKOLWebBrowser.DoComplete;
var
  hr: HResult;
  CustDoc: ICustomDoc;
begin
  hr := Document.QueryInterface( ICustomDoc, CustDoc );
  if hr = S_OK then CustDoc.SetUIHandler( handler );
  //FOleObject.DoVerb(OLEIVERB_UIACTIVATE, nil, fOleCtlIntf, 0, ParentWindow, BoundsRect);
end;

//==============================================================
function TDocHostUIHandler.EnableModeless(const fEnable: BOOL): HRESULT;
begin
  Result := S_FALSE;
end;

function TDocHostUIHandler.FilterDataObject(const pDO: IDataObject; out ppDORet: IDataObject): HRESULT;
begin
  Result := S_FALSE;
end;

function TDocHostUIHandler.GetDropTarget(const pDropTarget: IDropTarget; out ppDropTarget: IDropTarget): HRESULT;
begin
  Result := S_FALSE;
end;

function TDocHostUIHandler.GetExternal(out ppDispatch: IDispatch): HRESULT;
begin
  ppDispatch := web.GetProperty('Fun:Host');
  Result := S_OK;
end;

function TDocHostUIHandler.GetHostInfo(var pInfo: TDOCHOSTUIINFO): HRESULT;
begin
  //pInfo.cbSize  := SizeOf(pInfo);
  pInfo.dwFlags := 4; //DOCHOSTUIFLAG_NO3DBORDER;
  Result := S_OK;
end;

function TDocHostUIHandler.GetOptionKeyPath(var pchKey: POLESTR; const dw: DWORD): HRESULT;
begin
  Result := S_FALSE;
end;

function TDocHostUIHandler.HideUI: HRESULT;
begin
  Result := S_FALSE;
end;

function TDocHostUIHandler.OnDocWindowActivate(const fActivate: BOOL): HRESULT;
begin
  Result := S_FALSE;
end;

function TDocHostUIHandler.OnFrameWindowActivate(const fActivate: BOOL): HRESULT;
begin
  Result := S_FALSE;
end;

function TDocHostUIHandler.ResizeBorder(const prcBorder: PRECT; const pUIWindow: IOleInPlaceUIWindow; const fRameWindow: BOOL): HRESULT;
begin
  Result := S_FALSE;
end;

function TDocHostUIHandler.ShowContextMenu(const dwID: DWORD; const ppt: PPOINT; const pcmdtReserved: IUnknown; const pdispReserved: IDispatch): HRESULT;
begin
  Result := S_FALSE;
end;

function TDocHostUIHandler.ShowUI(const dwID: DWORD; const pActiveObject: IOleInPlaceActiveObject; const pCommandTarget: IOleCommandTarget; const pFrame:
        IOleInPlaceFrame; const pDoc: IOleInPlaceUIWindow): HRESULT;
begin
  Result := S_FALSE;
end;

function TDocHostUIHandler.TranslateAccelerator(const lpMsg: PMSG; const pguidCmdGroup: PGUID; const nCmdID: DWORD): HRESULT;
begin
  Result := S_FALSE;
end;

function TDocHostUIHandler.TranslateUrl(const dwTranslate: DWORD; const pchURLIn: POLESTR; var ppchURLOut: POLESTR): HRESULT;
begin
  Result := S_FALSE;
end;

function TDocHostUIHandler.UpdateUI: HRESULT;
begin
  Result := S_FALSE;
end;

end.

