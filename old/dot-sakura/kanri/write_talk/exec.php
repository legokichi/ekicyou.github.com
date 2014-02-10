<?php
//####################################################################
//
//    [ファイル名]
//    log_exec.php
//
//    [内容]
//    ボトルログ取り込み
//
//    [特記事項]
//    なし
//
//####################################################################
//====================================================================
// ヘッダＨＴＭＬ
//====================================================================
  require_once( "./login.pplb" );
  require_once( "./exec_main.pplb" );
  $err->init("トーク出力 | 「．さくら」データ出力 | 実行");

  $buf[TITLE ] = $err->title;
  $buf[HEADER] =TRUE;
  $buf[BODY  ] =TRUE;
  $buf[MESSAGE] ="出力処理中です。\nしばらくお待ちください。";
  TmplUty::out("../base.tmpl" ,$buf);

//====================================================================
// メインルーチン
//====================================================================

  while (@ob_end_clean());
  $conn =logonDB();
  $jobList[] =array(JOB_ID=>1, NAME=>"トーク出力");

  DButil::begin($conn);
  foreach($jobList as $job){
    set_time_limit(120);
    $JOB_ID =$job[JOB_ID];
    echo "■{$job[NAME]}....<br>\n";
    flush();
    $eval_str="job{$JOB_ID}" .'($conn, $err);';
    eval($eval_str);
    if($err->isError()) break;
  }
  if($err->isError()) DButil::rollback($conn);
  else                DButil::commit($conn);
  logoffDB($conn);
  $err->isErrorExit();

//####################################################################
// 更新処理本体　　＊＊ここまで＊＊
//####################################################################
  $err->isErrorExit();
  unset($buf);
  $buf[BODY  ] =TRUE;
  $buf[FOOTER ] =TRUE;
  $buf[MESSAGE] ="トーク出力が終了しました。";
  TmplUty::out("../base.tmpl" ,$buf);
?>