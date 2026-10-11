#include "sleep.h"
#include "xgpio.h"
#include "xil_printf.h"
#include "xil_io.h"
#include "xil_cache.h"
#include "xparameters.h"
#include "bspconfig.h"
#include "xuartps_hw.h"
#include <math.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#define CORE_BASE 0x43c00000U
#define FS_HZ 48828.125
#define CAPTURE_WORDS 32768U
#define CORE_GAINS 0x00U
#define CORE_OPTIONS 0x04U
#define CORE_UI 0x08U
#define CORE_COMMAND 0x0cU
#define CORE_CAPTURE 0x10U
#define CORE_LEVELS 0x14U
#define CORE_DIAG 0x18U
#define CORE_ID 0x20U
#define CORE_TARGET 0x24U
#define CORE_BUFFER 0x20000U
#define CORE_PRODUCED 0x28U
#define CORE_CONSUMED 0x2cU
#define CORE_LIMIT 0x30U
#define DDR_AUDIO_BASE 0x08000000U
#define DDR_AUDIO_BYTES 0x18000000U
#define DDR_AUDIO_FRAMES (DDR_AUDIO_BYTES/4U)
#define DDR_META_BASE 0x07fff000U
#define FS_NUM 1953125U
#define FS_DEN 40U
static XGpio gpio;
static unsigned int ctrl=0x1000003fU,gains=0x40404040U,options=0x12800020U;
static unsigned int cal_left=0,cal_sum[4],capture_active=0,cal_saturated=0;
static unsigned int log_enabled=0,log_tick=0;
static unsigned int long_active=0,long_state=0,long_frames=0,long_goal=0,long_crc=0xffffffffU,max_lag=0;
static unsigned int record_ctrl,record_gains,record_options,crc_table[256];
static unsigned int ddr_ok=0;
static void wr(unsigned int offset,unsigned int value);
static unsigned int rd(unsigned int offset);
static void record_meta(void){
 unsigned int meta[16]={0x41554452U,1,long_state,DDR_AUDIO_BASE,long_frames,long_goal,long_crc^0xffffffffU,
 record_ctrl,record_gains,record_options,max_lag,rd(CORE_CAPTURE),DDR_AUDIO_BYTES,FS_NUM,FS_DEN,64};
 for(unsigned int i=0;i<16;i++)Xil_Out32(DDR_META_BASE+4*i,meta[i]);
 Xil_DCacheFlushRange(DDR_META_BASE,64);
}
static int ddr_probe(void){
 unsigned int address[64],saved[64];int good=1;
 for(unsigned int i=0;i<256;i++){
  unsigned int c=i;for(unsigned int j=0;j<8;j++)c=(c>>1)^((c&1)?0xedb88320U:0);crc_table[i]=c;
 }
 for(unsigned int i=0;i<64;i++){
  address[i]=DDR_AUDIO_BASE+(i==63?DDR_AUDIO_BYTES-4:i*(DDR_AUDIO_BYTES/64));
  saved[i]=Xil_In32(address[i]);Xil_Out32(address[i],0x5a3c0000U^(i*0x10203U));
  Xil_DCacheFlushRange(address[i]&~31U,32);
 }
 for(unsigned int i=0;i<64;i++){
  Xil_DCacheInvalidateRange(address[i]&~31U,32);
  if(Xil_In32(address[i])!=(0x5a3c0000U^(i*0x10203U)))good=0;
 }
 for(unsigned int i=0;i<64;i++){Xil_Out32(address[i],saved[i]);Xil_DCacheFlushRange(address[i]&~31U,32);}
 return good;
}
static void record_info(void){
 xil_printf("RECINFO state=%d frames=%d goal=%d maxlag=%d crc=%08x base=%08x max_frames=%d max_seconds=2061 ddr_ok=%d\r\n",
 long_state,long_frames,long_goal,max_lag,long_crc^0xffffffffU,DDR_AUDIO_BASE,DDR_AUDIO_FRAMES,ddr_ok);
}
static void record_fail(void){
 wr(CORE_COMMAND,16);long_active=0;long_state=3;record_meta();
 xil_printf("REC_ERROR: ring overflow; incomplete recording rejected frames=%d\r\n",long_frames);
}
static void record_pump(void){
 if(!long_active)return;
 unsigned int head=rd(CORE_PRODUCED),lag=head-long_frames;
 if(lag>max_lag)max_lag=lag;
 if((rd(CORE_CAPTURE)&4U) || lag>CAPTURE_WORDS){record_fail();return;}
 unsigned int n=lag;if(n>2048U)n=2048U;if(n>long_goal-long_frames)n=long_goal-long_frames;
 unsigned int start=long_frames;
 volatile unsigned int *buffer=(volatile unsigned int *)DDR_AUDIO_BASE;
 for(unsigned int i=0;i<n;i++){
  unsigned int word=rd(CORE_BUFFER+4*((long_frames+i)&(CAPTURE_WORDS-1U)));
  buffer[long_frames+i]=word;
  for(unsigned int k=0;k<4;k++)long_crc=crc_table[(long_crc^(word>>(8*k)))&255U]^(long_crc>>8);
 }
 if(n){Xil_DCacheFlushRange(DDR_AUDIO_BASE+4*start,4*n);long_frames+=n;wr(CORE_CONSUMED,long_frames);}
 if(rd(CORE_CAPTURE)&4U){record_fail();return;}
 if(long_frames==long_goal){
  long_active=0;long_state=2;record_meta();
  xil_printf("REC_READY frames=%d bytes=%d crc=%08x maxlag=%d\r\n",long_frames,4*long_frames,long_crc^0xffffffffU,max_lag);
 }
}
static void record_start(unsigned int frames){
 if(!ddr_ok){xil_printf("REC_ERROR: DDR probe failed\r\n");return;}
 if(long_active || capture_active || cal_left || (rd(CORE_CAPTURE)&1U)){xil_printf("CAPTURE_BUSY\r\n");return;}
 long_frames=0;long_goal=frames;long_crc=0xffffffffU;max_lag=0;long_state=1;long_active=1;
 record_ctrl=ctrl;record_gains=gains;record_options=options;log_enabled=0;
 wr(CORE_COMMAND,2);wr(CORE_LIMIT,frames);wr(CORE_COMMAND,0x101U);record_meta();
 xil_printf("REC_STARTED frames=%d bytes=%d max_seconds=2061\r\n",frames,4*frames);
}
static void wr(unsigned int offset,unsigned int value){Xil_Out32(CORE_BASE+offset,value);}
static unsigned int rd(unsigned int offset){return Xil_In32(CORE_BASE+offset);}
static int sign9(unsigned int v){v&=511;return (v&256)?(int)v-512:(int)v;}
static int angle_of(int x,int y){
 if(x==0 && y==0)return -1;
 int a=(int)lround(atan2(-(double)x,-(double)y)*180.0/3.141592653589793);
 return (a+360)%360;
}
static unsigned int steer(unsigned int value,int angle){
 double radius=.05*FS_HZ/343.0*16.0,rad=angle*3.141592653589793/180.0;
 int x=(int)lround(-radius*sin(rad)),y=(int)lround(-radius*cos(rad));
 return (value&~((511u<<8)|(511u<<17)|32u))|(((unsigned int)x&511u)<<8)|(((unsigned int)y&511u)<<17);
}
static void apply(void){XGpio_DiscreteWrite(&gpio,1,ctrl);wr(CORE_GAINS,gains);wr(CORE_OPTIONS,options);}
static void print_status(void){
 unsigned int raw=XGpio_DiscreteRead(&gpio,2),target=rd(CORE_TARGET),diag=rd(CORE_DIAG);
 int x=sign9(raw),y=sign9(raw>>9),ok=(raw>>18)&1u;
 xil_printf("seq=%d valid=%d az=%d beam=%d x_q4=%d y_q4=%d peak_gate=%d clip=%d agc_q8=%d gate=%d band=%d band_clip=%d band_overrun=%d doa_overrun=%d fft_overrun=%d\r\n",raw>>24,ok,ok?angle_of(x,y):-1,angle_of(sign9(target),sign9(target>>9)),x,y,(raw>>19)&31,diag&31,(diag>>18)&4095,(diag>>7)&1,(ctrl&1u)?((options>>28)&3u):1u,(diag>>30)&1,(diag>>31)&1,(diag>>5)&1,(diag>>6)&1);
 xil_printf("HW GAINS=%08x OPTIONS=%08x CAPTURE=%08x DIAG=%08x\r\n",rd(CORE_GAINS),rd(CORE_OPTIONS),rd(CORE_CAPTURE),diag);
}
static void help(void){
 xil_printf("PRO commands: a auto; b beam; e EQ; r reverb; q quarter; m mic; t tone; p keys\r\n");
 xil_printf("0/1/2/3 front/right/back/left; angle 0..359; l lock; n gate; g AGC; u mute; f smoothing; band off/voice/wind/narrow\r\n");
 xil_printf("gain MIC(0..3) Q6(0..192); vol 0..128; gate 0..65535; smooth 1..7; cal; resetcal\r\n");
 xil_printf("v short record; d short binary dump; rec SECONDS(1..2061) / rec max; stop; recinfo; x clear clip; h help\r\n");
 xil_printf("Quiet UART default. s status; log on/off (1Hz); Ctrl-C stops log. Commands end with Enter.\r\n");
}
static void dump_audio(void){
 unsigned int state=rd(CORE_CAPTURE);
 if(!(state&2u) || (state>>16)!=CAPTURE_WORDS){xil_printf("CAPTURE_NOT_READY\r\n");return;}
 xil_printf("AUDIO_BEGIN bytes=131072 rate=48828 channels=2 bits=16 ctrl=%08x gains=%08x opts=%08x\r\n",ctrl,gains,options);
 for(unsigned int i=0;i<CAPTURE_WORDS;i++){
  unsigned int word=rd(CORE_BUFFER+4*i);
  for(unsigned int k=0;k<4;k++)outbyte((char)(word>>(8*k)));
 }
 xil_printf("\r\nAUDIO_END\r\n");
}
static void command(char *line){
 int index,value;
 if(!line[0])return;
 if(!strcmp(line,"recinfo")){record_info();return;}
 if(!strcmp(line,"stop")){
  if(!long_active){xil_printf("REC_NOT_ACTIVE\r\n");return;}
  wr(CORE_COMMAND,16);long_goal=rd(CORE_PRODUCED);record_pump();return;
 }
 if(!strcmp(line,"rec max")){record_start(DDR_AUDIO_FRAMES);return;}
 if(sscanf(line,"rec %d",&value)==1){
  if(value<1||value>2061){xil_printf("RANGE: rec 1..2061 seconds or rec max\r\n");return;}
  record_start((unsigned int)(((unsigned long long)value*FS_NUM)/FS_DEN));return;
 }
 if(!strcmp(line,"s")){print_status();return;}
 if(!strcmp(line,"log on")){log_enabled=1;log_tick=0;xil_printf("LOG=ON rate=1Hz\r\n");return;}
 if(!strcmp(line,"log off")){log_enabled=0;log_tick=0;xil_printf("LOG=OFF\r\n");return;}
 if(!strcmp(line,"h")){help();return;}
 if(long_active && strcmp(line,"s") && strcmp(line,"log off") && strcmp(line,"h")){
  xil_printf("REC_BUSY: stop before changing audio settings\r\n");return;
 }
 if(!strcmp(line,"v")){
  if(rd(CORE_CAPTURE)&1u){xil_printf("CAPTURE_BUSY\r\n");return;}
  long_state=0;record_meta();wr(CORE_COMMAND,1);capture_active=1;xil_printf("CAPTURE_STARTED\r\n");return;
 }
 if(!strcmp(line,"d")){dump_audio();return;}
 if(!strcmp(line,"x")){wr(CORE_COMMAND,4);xil_printf("CLIP_CLEARED\r\n");return;}
 if(!strcmp(line,"band off") || !strcmp(line,"band voice") || !strcmp(line,"band wind") || !strcmp(line,"band narrow")){
  unsigned int mode=!strcmp(line,"band voice")?1u:!strcmp(line,"band wind")?2u:!strcmp(line,"band narrow")?3u:0u;
  options=(options&~0x30000000u)|(mode<<28);ctrl|=1u;apply();
  xil_printf("BAND=%d OPTIONS=%08x (0=off 1=150-6000 2=300-4000 3=300-3400 Hz)\r\n",mode,options);return;
 }
 if(!strcmp(line,"cal")){
  gains=0x40404040U;wr(CORE_GAINS,gains);memset(cal_sum,0,sizeof(cal_sum));cal_left=600;cal_saturated=0;
  xil_printf("CAL_BEGIN: continuous centered source at >=1m; 1s warmup + 5s amplitude measurement\r\n");return;
 }
 if(!strcmp(line,"resetcal")){cal_left=0;gains=0x40404040U;apply();xil_printf("CAL_RESET\r\n");return;}
 if(sscanf(line,"angle %d",&value)==1){
  if(value<0||value>359){xil_printf("RANGE: angle 0..359\r\n");return;}
  ctrl=steer(ctrl|19u,value);
 }else if(sscanf(line,"gain %d %d",&index,&value)==2){
  if(index<0||index>3||value<0||value>192){xil_printf("RANGE: gain mic=0..3 q6=0..192\r\n");return;}
  cal_left=0;gains=(gains&~(255u<<(8*index)))|((unsigned int)value<<(8*index));
 }else if(sscanf(line,"vol %d",&value)==1){
  if(value<0||value>128){xil_printf("RANGE: vol 0..128\r\n");return;}
  options=(options&~0x00ff0000u)|((unsigned int)value<<16);
 }else if(sscanf(line,"gate %d",&value)==1){
  if(value<0||value>65535){xil_printf("RANGE: gate 0..65535\r\n");return;}
  options=(options&~65535u)|(unsigned int)value;
 }else if(sscanf(line,"smooth %d",&value)==1){
  if(value<1||value>7){xil_printf("RANGE: smooth 1..7\r\n");return;}
  options=(options&~0x07000000u)|((unsigned int)value<<24);
 }else if(strlen(line)==1){switch(line[0]){
  case 'a':ctrl|=0x10000033u;break;case 'b':ctrl^=16;ctrl|=1;break;case 'e':ctrl^=8;ctrl|=1;break;
  case 'r':ctrl^=64;ctrl|=1;break;case 'q':ctrl^=4;ctrl|=1;break;case 'm':ctrl|=3;break;case 't':ctrl=(ctrl|1)&~2u;break;
  case 'p':ctrl&=~1u;break;case 'n':ctrl^=128;ctrl|=1;break;case 'g':ctrl^=1u<<26;ctrl|=1;break;
  case 'u':ctrl^=1u<<27;ctrl|=1;break;case 'f':ctrl^=1u<<28;ctrl|=1;break;
  case '0':case '1':case '2':case '3':ctrl=steer(ctrl|19,90*(line[0]-'0'));break;
  case 'l':{
   unsigned int raw=XGpio_DiscreteRead(&gpio,2),target=rd(CORE_TARGET);
   if(!((raw>>18)&1u)){xil_printf("LOCK_FAILED: no valid source\r\n");return;}
   ctrl=(ctrl&~((511u<<8)|(511u<<17)|32u))|19u|((target&511u)<<8)|(((target>>9)&511u)<<17);break;
  }
  default:xil_printf("UNKNOWN: h for help\r\n");return;
 }}else{xil_printf("UNKNOWN: h for help\r\n");return;}
 apply();xil_printf("CTRL=%08x GAINS=%08x OPTIONS=%08x\r\n",ctrl,gains,options);
}
int main(void){
#ifdef SDT
 int rc=XGpio_Initialize(&gpio,XPAR_AXI_GPIO_0_BASEADDR);
#else
 int rc=XGpio_Initialize(&gpio,XPAR_AXI_GPIO_0_DEVICE_ID);
#endif
 if(rc!=XST_SUCCESS){xil_printf("GPIO INIT FAIL\r\n");return 1;}
 XGpio_SetDataDirection(&gpio,1,0);XGpio_SetDataDirection(&gpio,2,0xffffffff);
 xil_printf("AX7010 AUDIO PRO BOOT fs=48828.125 side=50mm\r\n");
 if(rd(CORE_ID)!=0xa7010404u){xil_printf("CORE_ID_FAIL: matching PRO bitstream required\r\n");return 1;}
 ddr_ok=ddr_probe();record_meta();xil_printf("DDR_RECORD capacity_bytes=%d max_seconds=2061 probe=%d\r\n",DDR_AUDIO_BYTES,ddr_ok);
 apply();help();
 char line[64];unsigned int length=0,tick=0;int dropping=0;
 while(1){
  record_pump();
  while(XUartPs_IsReceiveData(STDIN_BASEADDRESS)){
   unsigned char c=XUartPs_ReadReg(STDIN_BASEADDRESS,XUARTPS_FIFO_OFFSET);
   if(c==3){length=0;dropping=0;log_enabled=0;log_tick=0;xil_printf("\r\nLOG=OFF\r\n");}
   else if(c=='\r'||c=='\n'){
    if(length||dropping)xil_printf("\r\n");
    if(dropping)xil_printf("COMMAND_TOO_LONG\r\n");else{line[length]=0;command(line);}
    length=0;dropping=0;
   }else if(c==8||c==127){if(length){length--;xil_printf("\b \b");}}
   else if(c>=32&&c<=126){if(!dropping && length<sizeof(line)-1){line[length++]=(char)c;outbyte((char)c);}else dropping=1;}
  }
  if(cal_left){
   if(cal_left<=500){unsigned int meter=rd(CORE_LEVELS);for(unsigned int i=0;i<4;i++){unsigned int v=(meter>>(8*i))&255u;cal_sum[i]+=v;if(v==255)cal_saturated=1;}}
   if(--cal_left==0){
    unsigned int target=(cal_sum[0]+cal_sum[1]+cal_sum[2]+cal_sum[3])/4;
    int good=!cal_saturated;for(unsigned int i=0;i<4;i++)if(cal_sum[i]<1000)good=0;
    if(good){gains=0;for(unsigned int i=0;i<4;i++){
     unsigned int coefficient=(target*64+cal_sum[i]/2)/cal_sum[i];if(coefficient<32)coefficient=32;if(coefficient>128)coefficient=128;
     gains|=coefficient<<(8*i);
    }wr(CORE_GAINS,gains);xil_printf("CAL_DONE gains=%08x (volatile amplitude-only calibration)\r\n",gains);
    }else{xil_printf("CAL_FAILED: weak/missing or saturated meter; adjust source level, unity gains retained\r\n");}
   }
  }
  if(capture_active && (rd(CORE_CAPTURE)&2u)){capture_active=0;xil_printf("CAPTURE_READY samples=32768\r\n");}
  if(++tick==10){
   tick=0;unsigned int target=rd(CORE_TARGET);
   int beam_angle=angle_of(sign9(target),sign9(target>>9));
   unsigned int ui=0;
   if(beam_angle>=0)ui=(unsigned int)(beam_angle%10)|((unsigned int)(beam_angle/10%10)<<4)|((unsigned int)(beam_angle/100)<<8)|4096u;
   wr(CORE_UI,ui);if(long_active)record_meta();
   if(log_enabled && length==0 && !dropping && ++log_tick>=10){log_tick=0;print_status();}
  }
  usleep(10000);
 }
}
