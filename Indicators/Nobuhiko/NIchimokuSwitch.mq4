//+------------------------------------------------------------------+
//|                                              NIchimokuSwitch.mq4 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2017, Nobuhiko Akashi"
#property link      "http://fx.na-sys.mydns.jp/"
#property version   "1.01"
#property strict
#property indicator_chart_window

#property indicator_buffers 7
#property indicator_color1 clrNONE	// Tenkan-sen
#property indicator_color2 clrNONE	// Kijun-sen
#property indicator_color3 clrNONE	// Up Kumo
#property indicator_color4 clrNONE	// Down Kumo
#property indicator_color5 clrNONE	// Chikou Span
#property indicator_color6 clrNONE	// Up Kumo bounding line
#property indicator_color7 clrNONE	// Down Kumo bounding line


input int InpTenkan=9;   // Tenkan-sen
input int InpKijun=26;   // Kijun-sen
input int InpSenkou=52;  // Senkou Span B

input int IchimokuButtonX = 10;	//	ボタンのX座標
input int IchimokuButtonY = 15;	//	ボタンのY座標

input color TenkanColor = clrRed;
input color KijunColor = clrBlue;
input color SpanAColor = clrSandyBrown;
input color SpanBColor = clrThistle;
input color ChikouColor = clrLimeGreen;
input color SpanA2Color = clrSandyBrown;
input color SpanB2Color = clrThistle;

color originalSpanAColor_;
color originalSpanBColor_;
color originalSpanA2Color_;
color originalSpanB2Color_;


double ExtTenkanBuffer[];
double ExtKijunBuffer[];
double ExtSpanA_Buffer[];
double ExtSpanB_Buffer[];
double ExtChikouBuffer[];
double ExtSpanA2_Buffer[];
double ExtSpanB2_Buffer[];


enum E_ICHIMOKU_BUFFER_INDEX {
	ICHIMOKU_BUFFER_INDEX_TENKAN = 0,
	ICHIMOKU_BUFFER_INDEX_KIJUN,
	ICHIMOKU_BUFFER_INDEX_SPAN_A,
	ICHIMOKU_BUFFER_INDEX_SPAN_B,
	ICHIMOKU_BUFFER_INDEX_CHIKOU,
	ICHIMOKU_BUFFER_INDEX_SPAN_A2,
	ICHIMOKU_BUFFER_INDEX_SPAN_B2,
};

const string BUTTON_KUMO_ID = "NButtonIchimoku";



//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
	IndicatorDigits(Digits);
	
	//	ON/OFF用のボタンオブジェクトを生成
	if(ObjectFind(BUTTON_KUMO_ID) < 0) {
		ObjectCreate(0,BUTTON_KUMO_ID,OBJ_BUTTON,0,100,100);
		ObjectSetString(0,BUTTON_KUMO_ID,OBJPROP_TEXT,"Ichimoku");
		ObjectSetInteger(0,BUTTON_KUMO_ID,OBJPROP_XDISTANCE,IchimokuButtonX);
		ObjectSetInteger(0,BUTTON_KUMO_ID,OBJPROP_YDISTANCE,IchimokuButtonY);
		ObjectSetInteger(0, BUTTON_KUMO_ID, OBJPROP_XSIZE, 60);
		
		//	ボタン押下状態にする
		ObjectSetInteger(0, BUTTON_KUMO_ID, OBJPROP_STATE, 1);
	}
	
	bool selected = ObjectGetInteger(0,BUTTON_KUMO_ID, OBJPROP_STATE);
	
//--- indicator buffers mapping
	
//---
	SetIndexStyle(0,DRAW_LINE, EMPTY, EMPTY, selected ? TenkanColor : clrNONE);
	SetIndexBuffer(0,ExtTenkanBuffer);
	SetIndexDrawBegin(0,InpTenkan-1);
	SetIndexLabel(0,"Tenkan Sen");
	
	SetIndexStyle(1,DRAW_LINE, EMPTY, EMPTY, selected ? KijunColor : clrNONE);
	SetIndexBuffer(1,ExtKijunBuffer);
	SetIndexDrawBegin(1,InpKijun-1);
	SetIndexLabel(1,"Kijun Sen");
//---
	int ExtBegin=InpKijun;
	if(ExtBegin<InpTenkan) {
		ExtBegin=InpTenkan;
	}
//---
	SetIndexStyle(2,DRAW_HISTOGRAM,STYLE_DOT, EMPTY, selected ? SpanAColor : clrNONE);
	SetIndexBuffer(2,ExtSpanA_Buffer);
	SetIndexDrawBegin(2,InpKijun+ExtBegin-1);
	SetIndexShift(2,InpKijun);
	SetIndexLabel(2,NULL);
	SetIndexStyle(5,DRAW_LINE,STYLE_DOT, EMPTY, selected ? SpanA2Color : clrNONE);
	SetIndexBuffer(5,ExtSpanA2_Buffer);
	SetIndexDrawBegin(5,InpKijun+ExtBegin-1);
	SetIndexShift(5,InpKijun);
	SetIndexLabel(5,"Senkou Span A");
//---
	SetIndexStyle(3,DRAW_HISTOGRAM,STYLE_DOT, EMPTY, selected ? SpanBColor : clrNONE);
	SetIndexBuffer(3,ExtSpanB_Buffer);
	SetIndexDrawBegin(3,InpKijun+InpSenkou-1);
	SetIndexShift(3,InpKijun);
	SetIndexLabel(3,NULL);
	SetIndexStyle(6,DRAW_LINE,STYLE_DOT, EMPTY, selected ? SpanB2Color : clrNONE);
	SetIndexBuffer(6,ExtSpanB2_Buffer);
	SetIndexDrawBegin(6,InpKijun+InpSenkou-1);
	SetIndexShift(6,InpKijun);
	SetIndexLabel(6,"Senkou Span B");
//---
	SetIndexStyle(4,DRAW_LINE, EMPTY, EMPTY, selected ? ChikouColor : clrNONE);
	SetIndexBuffer(4,ExtChikouBuffer);
	SetIndexShift(4,-InpKijun);
	SetIndexLabel(4,"Chikou Span");
//---

	return(INIT_SUCCEEDED);
}
void OnDeinit(const int reason) {
	if(reason == REASON_REMOVE) {
		int objectsTotal = ObjectsTotal();
		for(int i = objectsTotal - 1; i >= 0; i--) {
			string objName = ObjectName(i);
			
			//	ボタンを削除
			if(BUTTON_KUMO_ID == objName) {
				ObjectDelete(objName);
			}
		}
	}
}



void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam) {
	if(id==CHARTEVENT_OBJECT_CLICK) {
		string clickedChartObject=sparam;
		if(clickedChartObject == BUTTON_KUMO_ID) {
			UpdateIchimoku();
		}
	}
}

void UpdateIchimoku() {
	bool selected = ObjectGetInteger(0,BUTTON_KUMO_ID, OBJPROP_STATE);
	
	SetIndexStyle(0,DRAW_LINE, EMPTY, EMPTY, (selected ? TenkanColor : clrNONE));
	SetIndexStyle(1,DRAW_LINE, EMPTY, EMPTY, (selected ? KijunColor : clrNONE));
	
	SetIndexStyle(2,DRAW_LINE, EMPTY, EMPTY, (selected ? SpanAColor : clrNONE));
	SetIndexStyle(3,DRAW_LINE, EMPTY, EMPTY, (selected ? SpanBColor : clrNONE));
	SetIndexStyle(2,DRAW_HISTOGRAM);
	SetIndexStyle(3,DRAW_HISTOGRAM);
	SetIndexStyle(4,DRAW_LINE, EMPTY, EMPTY, (selected ? ChikouColor : clrNONE));
	SetIndexStyle(5,DRAW_LINE, EMPTY, EMPTY, (selected ? SpanA2Color : clrNONE));
	SetIndexStyle(6,DRAW_LINE, EMPTY, EMPTY, (selected ? SpanB2Color : clrNONE));
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
                const int &spread[])
{
//---
	int period = rates_total - prev_calculated;

	for(int i = 0; i < period; i++) {
		
		double tenkan = iCustom(Symbol(), Period(), "Ichimoku", InpTenkan, InpKijun, InpSenkou, ICHIMOKU_BUFFER_INDEX_TENKAN, i);
		double kijun  = iCustom(Symbol(), Period(), "Ichimoku", InpTenkan, InpKijun, InpSenkou, ICHIMOKU_BUFFER_INDEX_KIJUN, i);
		double spanA  = iCustom(Symbol(), Period(), "Ichimoku", InpTenkan, InpKijun, InpSenkou, ICHIMOKU_BUFFER_INDEX_SPAN_A, i - InpKijun);
		double spanB  = iCustom(Symbol(), Period(), "Ichimoku", InpTenkan, InpKijun, InpSenkou, ICHIMOKU_BUFFER_INDEX_SPAN_B, i - InpKijun);
		double chikou = iCustom(Symbol(), Period(), "Ichimoku", InpTenkan, InpKijun, InpSenkou, ICHIMOKU_BUFFER_INDEX_CHIKOU, i + InpKijun);
		double spanA2  = iCustom(Symbol(), Period(), "Ichimoku", InpTenkan, InpKijun, InpSenkou, ICHIMOKU_BUFFER_INDEX_SPAN_A2, i - InpKijun);
		double spanB2  = iCustom(Symbol(), Period(), "Ichimoku", InpTenkan, InpKijun, InpSenkou, ICHIMOKU_BUFFER_INDEX_SPAN_B2, i - InpKijun);
		
		ExtTenkanBuffer[i] = tenkan;
		ExtKijunBuffer[i] = kijun;
		ExtSpanA_Buffer[i] = spanA;
		ExtSpanB_Buffer[i] = spanB;
		ExtChikouBuffer[i] = chikou;
		ExtSpanA2_Buffer[i] = spanA2;
		ExtSpanB2_Buffer[i] = spanB2;
	}
	

//--- return value of prev_calculated for next call
	return(rates_total -1);
}
//+------------------------------------------------------------------+
