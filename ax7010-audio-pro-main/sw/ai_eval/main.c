/* Offline PS inference benchmark. Live PL audio is muted while this app runs. */
#include "xparameters.h"
#include "xil_cache.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "rnnoise.h"
#include <stdint.h>
#include <stdlib.h>
#include <math.h>
#define META 0x07ffe000U
#define INPUT 0x08000000U
#define OUTPUT 0x10000000U
#define MAX_FRAMES 12001U
#define HOP 480U
static uint32_t durations[MAX_FRAMES], crc_table[256];
static float in[HOP],out[HOP];
static uint32_t meta[32];
static uint64_t ticks(void){
 uint32_t hi,lo;
 do{hi=Xil_In32(0xf8f00204U);lo=Xil_In32(0xf8f00200U);}while(hi!=Xil_In32(0xf8f00204U));
 return ((uint64_t)hi<<32)|lo;
}
static uint32_t micros(uint64_t elapsed){return (uint32_t)((elapsed*1000000U+XPAR_CPU_CORE_CLOCK_FREQ_HZ/2-1)/(XPAR_CPU_CORE_CLOCK_FREQ_HZ/2));}
static void publish(void){
 for(unsigned i=0;i<32;i++)Xil_Out32(META+4*i,meta[i]);
 Xil_DCacheFlushRange(META,128);
}
static void fail(uint32_t code){meta[2]=3;meta[5]=code;publish();while(1){}}
static uint32_t crc(const void *data,uint32_t bytes){
 const uint8_t *p=data;uint32_t c=~0U;
 for(uint32_t i=0;i<bytes;i++)c=crc_table[(c^p[i])&255]^(c>>8);
 return c^~0U;
}
static int compare(const void *a,const void *b){uint32_t x=*(const uint32_t*)a,y=*(const uint32_t*)b;return (x>y)-(x<y);}
int main(void){
 Xil_ICacheEnable();Xil_DCacheEnable();
 Xil_DCacheInvalidateRange(META,128);
 for(unsigned i=0;i<32;i++)meta[i]=Xil_In32(META+4*i);
 if(meta[0]!=0x41494556U || meta[1]!=1 || !meta[3] || meta[3]>MAX_FRAMES)fail(1);
 if(Xil_In32(0x43c00020U)!=0xa7010404U)fail(2);
 Xil_Out32(0x41200000U,0x1800003fU);
 Xil_Out32(0xf8f00208U,1U); /* CPU/2 global timer, prescaler zero. */
 const uint32_t frames=meta[3],bytes=frames*HOP*2;
 Xil_DCacheInvalidateRange(INPUT,bytes);
 for(unsigned i=0;i<256;i++){uint32_t c=i;for(unsigned j=0;j<8;j++)c=(c>>1)^((c&1)?0xedb88320U:0);crc_table[i]=c;}
 meta[19]=crc((void*)INPUT,bytes);
 if(meta[19]!=meta[4])fail(3);
 meta[2]=1;publish();
 uint64_t started=ticks();DenoiseState *state=(DenoiseState*)malloc((size_t)rnnoise_get_size());
 if(!state || rnnoise_get_frame_size()!=HOP)fail(4);
 if(rnnoise_init(state,NULL)!=0)fail(6);
 meta[24]=micros(ticks()-started);meta[18]=(uint32_t)rnnoise_get_size();
 const int16_t *src=(const int16_t*)INPUT;int16_t *dst=(int16_t*)OUTPUT;
 uint64_t total=0;uint32_t late=0,bad=0,clipped=0;double vad_sum=0;
 for(uint32_t f=0;f<frames;f++){
  uint64_t begin=ticks();
  for(unsigned i=0;i<HOP;i++)in[i]=(float)src[f*HOP+i];
  float vad=rnnoise_process_frame(state,out,in);
  for(unsigned i=0;i<HOP;i++){
   float value=out[i];
   if(!isfinite(value)){bad++;value=0;}
   if(value>32767){value=32767;clipped++;}else if(value< -32768){value=-32768;clipped++;}
   dst[f*HOP+i]=(int16_t)lrintf(value);
  }
  uint32_t us=micros(ticks()-begin);durations[f]=us;total+=us;if(us>10000)late++;
  if(!isfinite(vad))bad++;else vad_sum+=vad;
 }
 Xil_DCacheFlushRange(OUTPUT,bytes);
 meta[20]=crc((void*)OUTPUT,bytes);
 meta[6]=durations[0];qsort(durations,frames,sizeof(uint32_t),compare);
 meta[7]=(uint32_t)total;meta[8]=(uint32_t)(total>>32);
 meta[9]=durations[0];meta[10]=durations[frames-1];
 meta[11]=durations[((uint64_t)frames*95+99)/100-1];
 meta[12]=durations[((uint64_t)frames*99+99)/100-1];
 meta[16]=late;meta[17]=bad;meta[21]=XPAR_CPU_CORE_CLOCK_FREQ_HZ;
 meta[22]=XPAR_CPU_CORE_CLOCK_FREQ_HZ/2;meta[23]=48000;meta[25]=clipped;
 meta[26]=(uint32_t)(vad_sum*1000/frames);
 rnnoise_destroy(state);meta[2]=bad?3:2;meta[5]=bad?5:0;publish();
 xil_printf("AI_EVAL_DONE frames=%d mean_us=%d max_us=%d late=%d bad=%d\r\n",frames,(uint32_t)(total/frames),meta[10],late,bad);
 while(1){}
}
