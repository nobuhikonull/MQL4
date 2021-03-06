//+------------------------------------------------------------------+
//|                                           NTrendLineImporter.mq4 |
//|                                 Copyright 2018, Nobuhiko Akashi. |
//|                                       http://fx.na-sys.mydns.jp/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, Nobuhiko Akashi"
#property link      "http://fx.na-sys.mydns.jp/"
#property version   "1.03"
#property description "【概要】"
#property description "他のウィンドウからトレンドライン、水平ラインを取り込みます。"

#property strict
#property indicator_chart_window

/*
	v1.00 (2018/05/12)
		・新規作成
	v1.01 (2018/05/14)
		・ライン表示/非表示のボタンを設置
	v1.02 (2018/05/18)
		・他のインジケーターと競合する時にラインを非表示にする機能（無視リスト）を追加
		・時間軸の色を調整
	v1.03 (2018/05/18)
		・描画更新間隔をパラメータ化
		・ライン延長を同期
*/

enum E_BUTTON_ARRANGE_TYPE {
	BUTTON_ARRANGE_TYPE_H,	//	水平
	BUTTON_ARRANGE_TYPE_V,	//	垂直
};

//--- input parameters
//--- 各時間軸からコピーするラインの表示色
input color M1_LINE_COLOR = clrSnow;	//	M1のライン色
input color M5_LINE_COLOR = clrBlueViolet;	//	M5のライン色
input color M15_LINE_COLOR = clrRoyalBlue;	//	M15のライン色
input color M30_LINE_COLOR = clrTurquoise;	//	M30のライン色
input color H1_LINE_COLOR = clrLimeGreen;	//	H1のライン色
input color H4_LINE_COLOR = clrOrange;	//	H4のライン色
input color D1_LINE_COLOR = clrDeepPink;	//	D1のライン色
input color W1_LINE_COLOR = clrRed;	//	W1のライン色
input color MN1_LINE_COLOR = clrFireBrick;	//	MNのライン色

input bool IS_SHOW_BUTTON = true;	//	表示切替のボタンを表示するかどうか
input E_BUTTON_ARRANGE_TYPE BUTTON_ARRANGE_TYPE = BUTTON_ARRANGE_TYPE_V;	//	ボタン配置方向

input string IGNORE_LINE_NAME_STRING_LIST = "hthc_";	//	無視するライン名に含まれる文字列を指定（カンマ区切りで複数指定可能）
input int TIMER_INTERVAL = 50;	//	描画更新の間隔（ms）	※50以上の値を指定

//	他インジケーター競合問題用
string IGNORE_LINE_NAME_ARRAY[];

int IMPORT_TIMEFRAME_ARRAY[];
string IMPORT_OBJECT_PREFIX;

string BUTTON_OBJECT_PREFIX;
const int BUTTON_WIDTH = 35;	//	ボタン幅
const int BUTTON_HIGHT = 20;	//	ボタン高さ
const int BUTTON_MARGIN = 3;	//	ボタン間隔
const int FIRST_BUTTON_X = 10;	//	X座標
const int FIRST_BUTTON_Y = 15;	//	Y座標

const int TIMER_INTERVAL_MIN = 50;	//	描画更新間隔最小値

bool initialized_;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
//--- indicator buffers mapping
	initialized_ = true;
	string errorMessage = "";
	if(TIMER_INTERVAL < TIMER_INTERVAL_MIN) {
		initialized_ = false;
		errorMessage = StringConcatenate(errorMessage, "設定『描画更新の間隔』が無効な値です。\n");
	}
	
	int randNum = MathRand();
	InitObjectPrefix(randNum);
	
	EventSetMillisecondTimer(TIMER_INTERVAL);
	
	//	グローバル変数 IMPORT_TIMEFRAME_ARRAY の初期化
	InitTimeFrameArray();
	//	グローバル変数 IGNORE_LINE_NAME_ARRAY の初期化
	InitIgnoreLineNameArray();
	
	InitButtonPrefix(randNum);
	if(IS_SHOW_BUTTON) {
		InitButton();
	}
	
	if(initialized_ == false) {
		Alert(errorMessage);
	}
	
//---
	return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {
	//	タイマーの削除
	EventKillTimer();
	
	//	オブジェクトの削除
	int objectsTotal = ObjectsTotal();
	for(int i = objectsTotal -1; i >= 0; i--) {
		string objectName = ObjectName(i);
		
		//	取り込みラインの削除
		if(StringFind(objectName, IMPORT_OBJECT_PREFIX) == 0) {
			ObjectDelete(objectName);
		}
		//ボタンの削除
		else if(StringFind(objectName, BUTTON_OBJECT_PREFIX) == 0) {
			ObjectDelete(objectName);
		}
	}
}

void InitIgnoreLineNameArray() {
	ArrayResize(IGNORE_LINE_NAME_ARRAY, 0);
	StringSplit(IGNORE_LINE_NAME_STRING_LIST, ',', IGNORE_LINE_NAME_ARRAY);
}


void InitObjectPrefix(int randNum) {
	IMPORT_OBJECT_PREFIX = "N" + IntegerToString(randNum) + "_";
}
void InitButtonPrefix(int randNum) {
	BUTTON_OBJECT_PREFIX = "N" + IntegerToString(randNum) + "BUTTON_";
}


void InitTimeFrameArray() {
	ArrayResize(IMPORT_TIMEFRAME_ARRAY, 0);
	
	int importTimeframeArray[] = {
		PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30,
		PERIOD_H1, PERIOD_H4, PERIOD_D1, PERIOD_W1, PERIOD_MN1
	};
	
	int copyStartIndex;
	for(copyStartIndex = 0; copyStartIndex < ArraySize(importTimeframeArray); copyStartIndex++) {
		if(importTimeframeArray[copyStartIndex] == Period()) {
			break;
		}
	}
	
	if(copyStartIndex >= ArraySize(importTimeframeArray)) {
		Print("{E3CD6F80-81C3-4DBD-8B1B-B949853F1A3C}");
		ArrayFree(IMPORT_TIMEFRAME_ARRAY);
		return;
	}
	
	ArrayCopy(IMPORT_TIMEFRAME_ARRAY, importTimeframeArray, 0, copyStartIndex);
}

void InitButton() {
	
	const long chartId = 0;
	for(int i = 0; i < ArraySize(IMPORT_TIMEFRAME_ARRAY); i++) {
		int timeframe = IMPORT_TIMEFRAME_ARRAY[i];
		string buttonObjectName = GetButtonObjectName(timeframe);
		
		int x = FIRST_BUTTON_X;
		int y = FIRST_BUTTON_Y;
		switch(BUTTON_ARRANGE_TYPE) {
			case BUTTON_ARRANGE_TYPE_H:
				x += (BUTTON_WIDTH + BUTTON_MARGIN) * i;
				break;
			case BUTTON_ARRANGE_TYPE_V:
				y += (BUTTON_HIGHT + BUTTON_MARGIN) * i;
				break;
			default:
				Print("{C1B484A8-C8EF-466A-BB38-E032F510F5D0}");
				break;
		}
		
		string text = TimeframeToButtonText(timeframe);
		
		ObjectCreate(chartId, buttonObjectName, OBJ_BUTTON, 0, 0, 0);
		ObjectSetInteger(chartId, buttonObjectName, OBJPROP_XDISTANCE, x);
		ObjectSetInteger(chartId, buttonObjectName, OBJPROP_YDISTANCE, y);
		ObjectSetInteger(chartId, buttonObjectName, OBJPROP_XSIZE, BUTTON_WIDTH);
		ObjectSetInteger(chartId, buttonObjectName, OBJPROP_YSIZE, BUTTON_HIGHT);
		ObjectSetInteger(chartId, buttonObjectName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
		ObjectSetString(chartId, buttonObjectName, OBJPROP_TEXT, text);
		ObjectSetInteger(chartId, buttonObjectName, OBJPROP_STATE, true);
		
		ObjectSetInteger(chartId, buttonObjectName, OBJPROP_COLOR, GetLineColor(timeframe));
	}
}

bool ButtonPressed(int timeframe) {

	//	ボタンが表示されていない場合はボタンが押されているものとして扱う
	if(IS_SHOW_BUTTON == false) {
		return true;
	}

	const int chartId = 0;
	string buttonObjectName = GetButtonObjectName(timeframe);
	int objectsTotal = ObjectsTotal();
	for(int i = 0; i < objectsTotal; i++) {
		if(ObjectName(i) == buttonObjectName) {
			//Print("ObjectGetInteger(chartId, buttonObjectName, OBJPROP_STATE): ", ObjectGetInteger(chartId, buttonObjectName, OBJPROP_STATE));
			return ObjectGetInteger(chartId, buttonObjectName, OBJPROP_STATE);
		}
	}
	
	return false;
}

string GetButtonObjectName(int timeframe) {
	return BUTTON_OBJECT_PREFIX + IntegerToString(timeframe) + "_" + TimeframeToButtonText(timeframe);
}

string TimeframeToButtonText(int timeframe) {
	switch(timeframe) {
		case PERIOD_M1:		return "M1";
		case PERIOD_M5:		return "M5";
		case PERIOD_M15:	return "M15";
		case PERIOD_M30:	return "M30";
		case PERIOD_H1:		return "H1";
		case PERIOD_H4:		return "H4";
		case PERIOD_D1:		return "D1";
		case PERIOD_W1:		return "W1";
		case PERIOD_MN1:	return "MN";
		default:
			Print("{0D53E532-9F0A-4027-9F6E-7969D4205766}");
			return "";
	}
}

//	他のチャートで削除されたオブジェクトを現在のチャートからも削除する
void CleanDeletedObject() {
	int objectsTotal = ObjectsTotal();
	for(int objix = objectsTotal -1; objix >= 0; objix--) {
		string objectName = ObjectName(objix);
		
		//	取り込んだオブジェクトでない場合はスキップ
		if(StringFind(objectName, IMPORT_OBJECT_PREFIX) < 0) {
			continue;
		}
		//	コピー元のオブジェクト名に変換
		string originalObjectName = objectName;
		StringReplace(originalObjectName, IMPORT_OBJECT_PREFIX, "");
		
		bool isFind = false;
		long targetChartId = ChartFirst();
		while(targetChartId >= 0) {
		
			//	取り込み対象でない時間軸はスキップ
			if(IsImportTargetTimeframe(ChartPeriod(targetChartId)) == false) {
				targetChartId = ChartNext(targetChartId);
				continue;
			}
		
			//	コピー元のオブジェクトがまだ存在しているかどうかをチェック
			int targetObjerctsTotal = ObjectsTotal(targetChartId, 0);
			for(int toix = 0; toix < targetObjerctsTotal; toix++) {
				string targetObjectName = ObjectName(targetChartId, toix, 0);
				if(targetObjectName == originalObjectName) {
					isFind = true;
					break;
				}
			}
			if(isFind) {
				break;
			}
			targetChartId = ChartNext(targetChartId);
		}
		
		//	コピー元のオブジェクトが存在しない場合は削除
		if(isFind == false) {
			//Print("objectName: ", objectName);
			ObjectDelete(objectName);
		}
		
	}
}


void OnTimer() {
	
	if(initialized_ == false) {
		return;
	}

	//	トレンドラインの更新
	CopyChartObject(OBJ_TREND);
	
	//	水平ラインの更新
	CopyChartObject(OBJ_HLINE);
	
	//	コピー元のオブジェクトが削除されている場合は現在のチャートからも削除
	CleanDeletedObject();
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

color GetLineColor(int timeframe) {
	switch(timeframe) {
		case PERIOD_M1: 	return M1_LINE_COLOR;
		case PERIOD_M5: 	return M5_LINE_COLOR;
		case PERIOD_M15:	return M15_LINE_COLOR;
		case PERIOD_M30:	return M30_LINE_COLOR;
		case PERIOD_H1: 	return H1_LINE_COLOR;
		case PERIOD_H4: 	return H4_LINE_COLOR;
		case PERIOD_D1: 	return D1_LINE_COLOR;
		case PERIOD_W1: 	return W1_LINE_COLOR;
		case PERIOD_MN1: 	return MN1_LINE_COLOR;
		default:
			Print("{113C0F84-8679-42ED-8823-F69BB19711FC}");
			return clrNONE;
	}
}

bool IsImportTargetTimeframe(int timeframe) {
	for(int i = ArraySize(IMPORT_TIMEFRAME_ARRAY) -1; i >= 0; i--) {
		if(IMPORT_TIMEFRAME_ARRAY[i] == timeframe) {
			//return true;
			return ButtonPressed(timeframe);
		}
	}
	return false;
}

void CopyChartObject(ENUM_OBJECT objectType) {
	long currentChartId = ChartFirst(); 
	//long prevChart;
	
	while(currentChartId >= 0) {
		
		//	以下の条件の時、スキップ
		if(
			(ChartID() == currentChartId) ||								//	自分自身のチャート画面
			(Symbol() != ChartSymbol(currentChartId)) || 					//	または異なる通過ペア
			(IsImportTargetTimeframe(ChartPeriod(currentChartId)) == false)	//	または表示する時間軸でない場合
		) {
			currentChartId = ChartNext(currentChartId);
			continue;
		}
		
		string trendLineObjectNameArray[];
		GetAllObjectName(trendLineObjectNameArray, currentChartId, objectType);
		
		for(int objIndex = 0; objIndex < ArraySize(trendLineObjectNameArray); objIndex++) {
			
			string objectName = trendLineObjectNameArray[objIndex];	//	コピー元オブジェクト名
			string newObjectName = IMPORT_OBJECT_PREFIX + objectName;	//	コピー後のオブジェクト名
			
			//	コピー元のオブジェクト名が無視リストに在る場合はスキップ
			bool isSkip = false;
			for(int i = ArraySize(IGNORE_LINE_NAME_ARRAY) -1; i >= 0; i--) {
				string ignoreLineName = IGNORE_LINE_NAME_ARRAY[i];
				if(StringLen(ignoreLineName) > 0 && StringFind(objectName, ignoreLineName) >= 0) {
					isSkip = true;
					break;
				}
			}
			if(isSkip) {
				continue;
			}
			
			switch(objectType) {
				case OBJ_TREND:
					CopyTrendLine(currentChartId, objectName, newObjectName);
					break;
				case OBJ_HLINE:
					CopyHLine(currentChartId, objectName, newObjectName);
					break;
				default:
					Print("{515A8EDE-F4DF-4F38-9BF1-FB145F3B1E4C}");
					break;
			}
		}
		
		currentChartId = ChartNext(currentChartId);
	}
}


//	水平ラインの更新
void CopyHLine(long srcChartId, string srcHLineName, string dstHLineName) {
	//ObjectCreate(chart_ID,name,OBJ_HLINE,sub_window,0,price)) 
	
	double rate = ObjectGetDouble(srcChartId, srcHLineName, OBJPROP_PRICE);
	long lineWidth = ObjectGetInteger(srcChartId, srcHLineName, OBJPROP_WIDTH);
	
	if(ObjectFind(dstHLineName) < 0) {
		ObjectCreate(0, dstHLineName, OBJ_HLINE, 0, 0, rate);
	}
	else {
		ObjectMove(dstHLineName, 0, 0, rate);
	}
	
	color lineColor = GetLineColor(ChartPeriod(srcChartId));
	ObjectSet(dstHLineName, OBJPROP_COLOR, lineColor);
	ObjectSetInteger(0, dstHLineName, OBJPROP_WIDTH, lineWidth);
}

//	トレンドラインの更新
void CopyTrendLine(long srcChartId, string srcTrendLineName, string dstTrendLineName) {
	
	datetime timeBegin = (datetime)ObjectGetInteger(srcChartId, srcTrendLineName, OBJPROP_TIME);
	datetime timeEnd = (datetime)ObjectGetInteger(srcChartId, srcTrendLineName, OBJPROP_TIME, 1);
	double rateBegin = ObjectGetDouble(srcChartId, srcTrendLineName, OBJPROP_PRICE);
	double rateEnd = ObjectGetDouble(srcChartId, srcTrendLineName, OBJPROP_PRICE, 1);
	long lineWidth = ObjectGetInteger(srcChartId, srcTrendLineName, OBJPROP_WIDTH);
	bool rayRight = ObjectGetInteger(srcChartId, srcTrendLineName, OBJPROP_RAY_RIGHT);
	
	if(ObjectFind(dstTrendLineName) < 0) {
		ObjectCreate(0, dstTrendLineName, OBJ_TREND, 0, timeBegin, rateBegin, timeEnd, rateEnd);
	}
	else {
		ObjectMove(dstTrendLineName, 0, timeBegin, rateBegin);
		ObjectMove(dstTrendLineName, 1, timeEnd, rateEnd);
	}
	
	color trendLineColor = GetLineColor(ChartPeriod(srcChartId));
	ObjectSet(dstTrendLineName, OBJPROP_COLOR, trendLineColor);
	ObjectSetInteger(0, dstTrendLineName, OBJPROP_WIDTH, lineWidth);
	ObjectSetInteger(0, dstTrendLineName, OBJPROP_RAY_RIGHT, rayRight);
}

//	指定したオブジェクト種別の名称を引数の配列に格納します。
void GetAllObjectName(string &result[], long chartId, ENUM_OBJECT objectType) {
	ArrayResize(result, 0);
	int objectsTotal = ObjectsTotal(chartId, 0);
	for(int i = 0; i < objectsTotal; i++) {
		string objectName = ObjectName(chartId, i);
		if(ObjectGetInteger(chartId, objectName, OBJPROP_TYPE) == objectType) {
			ArrayResize(result, ArraySize(result) + 1);
			result[ArraySize(result) -1] = objectName;
		}
	}
}