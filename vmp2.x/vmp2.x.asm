VAR OEP                                  ;ԭʼ��ڵ�
VAR text_base                            ;.text����ʼ��ַ 
VAR text_size                            ;.text�����ڴ��еĴ�С
VAR vmp0_base                            ;.vmp0����ʼ��ַ 
VAR vmp0_size                            ;.vmp0�����ڴ��еĴ�С
VAR vmp1_base                            ;.vmp1�����ڴ��еĴ�С
VAR cnt_retn                             ;����IAT���ܵ����������������Ŀ���ת��������ַ��retn
VAR cnt_call                             ;�����ܵ�call������
VAR cnt_jmp                              ;�����ܵ�jmp������
VAR call_base                            ;�����ܵ�call�ĵ�ַ
VAR call_dst                             ;������call��Ŀ���ַ
VAR call_retn_addr                       ;������call�ķ��ص�ַ
VAR jmp_base                             ;�����ܵ�jmp�ĵ�ַ
VAR jmp_dst                              ;������jmp��Ŀ���ַ
VAR before_esp                           ;����call��jmpִ��ǰ��esp��ͨ���Ƚ�esp�ж�ԭʼ��call����jmp
VAR status                               ;�����޸�call����jmp��0����call��1����jmp
VAR exception_address                    ;KiUserExceptionDispatcher������ַ
VAR i                                    ;ѭ������
                                  

;----------------------------�ű����߼�-----------------------------------------
MOV text_base, 00401000                  ;[��Ҫ�޸�]��ʼ���������������Ҫ����ʵ������޸�
MOV text_size, 00002000
MOV vmp0_base, 00406000
MOV vmp0_size, 00006000
MOV vmp1_base, 0040C000

CALL FindOEP
CALL HookException
CALL FixIAT
MOV eip, OEP
BC
RET
;-------------------------------------------------------------------------------



FindOEP:                                 ;ͨ��һ���ڴ���ʶϵ����OEP
BPRM text_base, text_size
RUN
MOV OEP, eip
CMT eip, "������OEP"
BPMC
RET

--------------------------------------------------------------------------------
HookException:                                   ;���ټ����������������ָ��������ָ���м�ʱ��ֱ��ת��ȥ���úܴ���ʳ��쳣
GPA "KiUserExceptionDispatcher","ntdll.dll"      ;ͨ��hook�ķ�ʽ�����쳣��������
MOV exception_address, $RESULT
BP exception_address
BPGOTO exception_address, HookCallback
RET

HookCallback:
CMP status,0
JNE JmpException
  EVAL "�޸�callʱ�����쳣��address = {call_base}"
  LOG $RESULT
  JMP Loop_FixCall
JmpException:
  EVAL "�޸�jmpʱ�����쳣��address = {jmp_base}"
  LOG $RESULT
  JMP Loop_FixJmp
--------------------------------------------------------------------------------


FixIAT:
FINDCMD vmp0_base, "push dword ptr ss:[esp+const];retn const"
GREF
MOV cnt_retn, $RESULT
MOV i, 0
Loop_SetBreakPoint:
  INC i
  GREF i
  BP $RESULT+4
  CMP i,cnt_retn
JB Loop_SetBreakPoint
LOG cnt_retn, "���öϵ���ϣ����� = "

FINDCMD text_base, "call const"                ;���������Ǳ����ܵ�call����¼����
GREF
MOV cnt_call, $RESULT
MOV i, 0
MOV status, 0
Loop_FixCall:
  INC i  
  CMP i, cnt_call  
  JA Loop_FixCallEnd
  GREF i
  MOV call_base, $RESULT                       ;��ȡ��ǰcall�ĵ�ַ��Ŀ���ַ
  GCI call_base, DESTINATION
  MOV call_dst, $RESULT
  CMP call_dst, vmp0_base                      ;�ж��Ƿ���call��vmp0����ڣ�������ǣ�����
  JB Loop_FixCall
  CMP call_dst, vmp1_base
  JAE Loop_FixCall
    
  MOV eip, call_base                            
  MOV before_esp, esp        
  Loop_FindLastRetn1:                            ;��ʼ��ȡ����api�ĵ�ַ
    RUN
    STI
    GN eip
    CMP $RESULT, 0
  JE Loop_FindLastRetn1
                                      
  MOV call_retn_addr, [esp]                      ;��ȡ���ص�ַ
  SUB call_retn_addr, call_base                  
  CMP call_retn_addr, 5                          ;����Ϊcall���ҷ��ֽ�Ϊ��һ�ֽ�
  JNE FixCall_2
    EVAL "call {eip}"                              
    ASM call_base-1, $RESULT
    JMP Loop_FixCall
  FixCall_2:    
  CMP call_retn_addr, 6                          ;����Ϊcall���ҷ��ֽ�Ϊ�����ֽ�
  JNE FixCall_3
    EVAL "call {eip}"                              
    ASM call_base, $RESULT                         
    JMP Loop_FixCall      
  FixCall_3:
  CMP before_esp, esp                            ;ԭʼespС�ڵ���apiʱ��esp��(���Ϊ4��8)�Ҽ��ܺ���÷�ʽΪjmp��˵��ѹ�����������ݡ�
  JAE FixCall_4                                   ;����Ϊjmp�����ֽ�Ϊ��һ�ֽ�
    EVAL "jmp {eip}"                              
    ASM call_base-1, $RESULT
    JMP Loop_FixCall                                             
  FixCall_4:                                     ;����Ϊjmp�����ֽ�Ϊ�����ֽ�
    EVAL "jmp {eip}"                              
    ASM call_base, $RESULT
    JMP Loop_FixCall                                           
  FixCall_Unknown:                               ;δ֪���
  LOG call_base, "�޸�call����δ֪�����addr = "
  PAUSE
  Loop_FixCallEnd:
  LOG cnt_call, "�޸�call��ϣ����� = "


FINDCMD text_base, "jmp const"                   ;���������Ǳ����ܵ�jmp����¼����
GREF
MOV cnt_jmp, $RESULT
MOV i, 0
MOV status, 1
Loop_FixJmp:
  INC i  
  CMP i, cnt_jmp  
  JA Loop_FixJmpEnd
  GREF i
  MOV jmp_base, $RESULT                       ;��ȡ��ǰjmp�ĵ�ַ��Ŀ���ַ
  GCI jmp_base, DESTINATION
  MOV jmp_dst, $RESULT
  CMP jmp_dst, vmp0_base                      ;�ж��Ƿ���jmp��vmp0����ڣ�������ǣ�����
  JB Loop_FixJmp
  CMP jmp_dst, vmp1_base
  JAE Loop_FixJmp

  MOV eip, jmp_base                            
  MOV before_esp, esp        
  Loop_FindLastRetn2:                            ;��ʼ��ȡ����api�ĵ�ַ
    RUN
    STI
    GN eip
    CMP $RESULT, 0
  JE Loop_FindLastRetn2
                                      
  MOV call_retn_addr, [esp]                      ;��ȡ���ص�ַ
  SUB call_retn_addr, jmp_base                  
  CMP call_retn_addr, 5                          ;����Ϊcall���ҷ��ֽ�Ϊ��һ�ֽ�
  JNE FixJmp_2
    EVAL "call {eip}"                              
    ASM jmp_base-1, $RESULT
    JMP Loop_FixJmp
  FixJmp_2:    
  CMP call_retn_addr, 6                         ;����Ϊcall���ҷ��ֽ�Ϊ�����ֽ�
  JNE FixJmp_3
    EVAL "call {eip}"                              
    ASM jmp_base, $RESULT                         
    JMP Loop_FixJmp      
  FixJmp_3:
  CMP before_esp, esp                           ;ԭʼespС�ڵ���apiʱ��esp��(���Ϊ4��8)�Ҽ��ܺ���÷�ʽΪjmp��˵��ѹ�����������ݡ�
  JAE FixJmp_4                                  ;����Ϊjmp�����ֽ�Ϊ��һ���ֽ�
    EVAL "jmp {eip}"                              
    ASM jmp_base-1, $RESULT
    JMP Loop_FixJmp                                             
  FixJmp_4:                                     ;����Ϊjmp�����ֽ�Ϊ�����ֽ�
    EVAL "jmp {eip}"                              
    ASM jmp_base, $RESULT
    JMP Loop_FixJmp                                           
  FixJmp_Unknown:                               ;δ֪���
  LOG jmp_base, "�޸�jmp����δ֪�����addr = "
  PAUSE
  Loop_FixJmpEnd:
  LOG cnt_jmp, "�޸�jmp��ϣ����� = "
RET

;-------------------------------------------------------------------------------
