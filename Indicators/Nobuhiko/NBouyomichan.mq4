//+------------------------------------------------------------------+
//|                                                 NBouyomichan.mq4 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2017, Nobuhiko Akashi"
#property link      "http://fx.na-sys.mydns.jp/"
#property version   "1.04"
#property strict
#property indicator_chart_window

#import "shell32.dll"
	int ShellExecuteW(int hWnd,string lpVerb,string lpFile,string lpParameters,string lpDirectory,int nCmdShow);
#import

//	※ 自分の環境の RemoteTalk.exe があるパスに変更してください。
input string REMOTE_TALK_PATH = "C:\\Users\\Nobuhiko\\Documents\\Programs\\BouyomiChan\\BouyomiChan_0_1_11_0_Beta16\\RemoteTalk\\RemoteTalk.exe";
input int INTERVAL_SEC = 60;	//	棒読み間隔（秒）

/*	更新履歴

	v1.03 (2018/05/01)
		・Bidの値取得処理を『Bid』から『iClose』に変更
	v1.04 (2018/05/01)
		・棒読みの起動間隔を指定するパラメータ追加
*/

datetime lastAlertDatetime_ = (datetime)0;	//	最後に棒読みを起動した時刻

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
//--- indicator buffers mapping
	
	EventSetMillisecondTimer(1000);
//---
	return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
//---
	EventKillTimer();
}
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[]) {
//---
	
//--- return value of prev_calculated for next call
	return(rates_total);
}
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer() {
//---
	if(IsAlertStatus()) {
		
		lastAlertDatetime_ = TimeCurrent();	//	棒読み起動時間を更新
		
		RefreshRates();
		double bid = iClose(Symbol(), Period(), 0);	//	チャートのBidを取得
		string message = DoubleToString(bid, Digits);
		Bouyomi(message);
	}
}
//+------------------------------------------------------------------+

//	棒読みを起動するタイミングかどうかを返します。
bool IsAlertStatus() {
	
	if(lastAlertDatetime_ == (datetime)0) {
		return true;
	}

	datetime now = TimeCurrent();
	
	//	経過時間（秒）を取得
	double elapsed = ((double)now - (double)lastAlertDatetime_);
	
	return elapsed >= INTERVAL_SEC;
}

//	棒読みを起動します。
void Bouyomi(string message) {
	ShellExecuteW(0, "", "\"" + REMOTE_TALK_PATH + "\"", "/Talk " + message, "", 0);
}