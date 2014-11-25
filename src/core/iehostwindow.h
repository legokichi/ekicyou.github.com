#pragma once

#include <windows.h>
#include <atlbase.h>
#include <atlwin.h>
#include <atlcom.h>
#include <atlapp.h>
#include <atlcrack.h>
#include <agents.h>
#include "messages.h"

using namespace shiori;

class IEHostWindow :
    public CWindowImpl < IEHostWindow, CAxWindow, CWinTraits<WS_OVERLAPPEDWINDOW>>
{
public:
    static HANDLE CreateThread(
        HINSTANCE hinst,
        BSTR loaddir,
        RequestQueue &qreq,
        ResponseQueue &qres,
        concurrency::single_assignment<IEHostWindow*> &lazyWin,
        DWORD &thid);

    static DWORD WINAPI ThreadProc(LPVOID data);

public:
    IEHostWindow();
    virtual ~IEHostWindow();

    void Init(const HINSTANCE hinst, const BSTR &loaddir, RequestQueue &qreq, ResponseQueue &qres);

private:
    HINSTANCE hinst;
    BSTR loaddir;
    RequestQueue *qreq;
    ResponseQueue *qres;

private:
    HANDLE hthread;
    DWORD thid;

public:
    DECLARE_WND_CLASS(_T("IEHostWindow"));

    BEGIN_MSG_MAP(LayeredWindow)
        MSG_WM_CREATE(OnCreate)
        MSG_WM_DESTROY(OnDestroy)
        MESSAGE_HANDLER(WM_SHIORI_REQUEST, OnShioriRequest)
    END_MSG_MAP()


private:
    LRESULT OnDestroy();
    LRESULT OnCreate(LPCREATESTRUCT lpCreateStruct);
    LRESULT OnShioriRequest(UINT nMsg, WPARAM wParam, LPARAM lParam, BOOL& bHandled);
};