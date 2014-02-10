/* ----------------------------------------------------------------------------
 * tunaki_init.h
 *   つなき・初期化＆iniファイルアクセス関数.
 * ----------------------------------------------------------------------------
 * Mastering programed by Dot-Station Mastor
 *
 * Copyright 2004 Dot-Station.
 * ----------------------------------------------------------------------------
 * $Id: tunaki_init.h,v 1.1 2004/03/30 23:10:55 cvs Exp $
 * ----------------------------------------------------------------------------
 */
#ifndef TUNAKI_INIT_H__
#define TUNAKI_INIT_H__

#include "tunaki_def.h"


/* ----------------------------------------------------------------------------
 * 関数宣言
 */

/* コンストラクタ */
extern BOOL tunaki_construct(
      PTUNAKI t,                // TUNAKI 構造体
      HGLOBAL hGlobalLoaddir,   // DLLのベースディレクトリを格納するヒープ
      SIZE_T  loaddirLength     // ベースディレクトリの文字長
  );

/* デストラクタ */
extern BOOL tunaki_destruct(
      PTUNAKI t // TUNAKI 構造体
  );


/* ----------------------------------------------------------------------------
 * EOF
 */
#endif
