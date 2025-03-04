
100 REM TEST FOR DA$, TI$, BIN$(), HEX$()
110 REM ON COMMANDER X16
120 REM JEREMY DILATUSH, 4 SEP 2021
130 :
140 REM WILL SOMETIMES FAIL BECAUSE TI$ KEEPS CHANGING
150 REM IF SO RUN AGAIN
160 REM ALSO, BE SURE TO USE -RTC OPTION TO EMULATOR
170 :
190 COLOR3,0:SCREEN2:CLS
200 A$=DA$+TI$
210 B$=DA$+""
220 B$=B$+TI$+""
230 T$="DA$+TI$"
240 GOSUB3000
290 :
300 A$=BIN$(11011)
310 B$="0010101100000011"
320 T$="BIN$(11011)"
330 GOSUB3000
390 :
400 A$=HEX$(12345)
410 B$="3039"
420 T$="HEX$(12345)"
430 GOSUB3000
490 :
500 A$=DA$+BIN$(9)
510 B$=""+DA$+"00001001"
520 T$="DA$+BIN$(9)"
530 GOSUB3000
590 :
600 A$=TI$+HEX$(99)
610 B$=TI$
620 B$=B$+"63"
630 T$="TI$+HEX$(99)"
640 GOSUB3000
690 :
700 A$=BIN$(23456)+BIN$(34567)
710 B$="01011011101000001000011100000111"
720 T$="BIN$(23456)+BIN$(34567)"
730 GOSUB3000
790 :
800 A$=HEX$(111)+HEX$(222)
810 B$="6FDE"
820 T$="HEX$(111)+HEX$(222)"
830 GOSUB3000
890 :
900 A$=TI$+DA$
910 B$=TI$+""
920 C$=DA$+""
930 B$=B$+C$
940 T$="TI$+DA$"
950 GOSUB3000
990 :
1000 A$=TI$:C$=DA$:REM SAME LINE
1010 D$=DA$:B$=TI$
1020 T$="SAME LINE COLON"
1030 GOSUB3000
1090 :
1100 A$="<"+DA$+">"
1110 B$=DA$
1120 B$="<"+B$
1130 B$=B$+">"
1140 T$="BRACKET DA$"
1150 GOSUB3000
1190 :
1200 A$="<"+TI$+">"
1210 B$=TI$
1220 B$=B$+">"
1230 B$="<"+B$
1240 T$="BRACKET TI$"
1250 GOSUB3000
1290 :
1300 A$="<"+BIN$(65535)+">"
1310 B$="<1111111111111111>"
1320 T$="BRACKET BIN$()"
1330 GOSUB3000
1390 :
1400 A$="<"+HEX$(65535)+">"
1410 B$="<FFFF>"
1420 T$="BRACKET HEX$()"
1430 GOSUB3000
1490 :
1500 A$=DA$
1510 B$="YYYYHHMM"
1515 T$="DA$ PATTERN"
1520 IFLEN(A$)<>8THENGOSUB3100:GOTO1700
1530 FORI=1TO8
1540 C=ASC(MID$(A$,I,1))
1550 IFC<48ORC>57THENGOSUB3100:GOTO1700
1560 NEXT
1570 C$=LEFT$(A$,2)
1580 IFC$<>"19"ANDC$<>"20"THENGOSUB3100:GOTO1700
1590 M=VAL(MID$(A$,5,2))
1600 IFM<1ORM>12THENGOSUB3100:GOTO1700
1610 D=VAL(RIGHT$(A$,2))
1620 IFD<1ORD>31THENGOSUB3100:GOTO1700
1630 GOSUB3200
1690 :
1700 A$=TI$
1710 B$="HHMMSS"
1715 T$="TI$ PATTERN"
1720 IFLEN(A$)<>6THENGOSUB3100:GOTO1800
1730 FORI=1TO6
1740 C=ASC(MID$(A$,I,1))
1750 IFC<48ORC>57THENGOSUB3100:GOTO1800
1755 NEXT
1760 GOSUB3200
1790 :
1800 A$=LEFT$(DA$,4)+MID$(TI$,3,2)
1810 B$=DA$+"X"
1820 C$=TI$+"X"
1830 B$=LEFT$(B$,4)+MID$(C$,3,2)
1840 T$="YEARS AND MINUTES"
1850 GOSUB3200
1890 :
2900 PRINTFC;" FAILURES"
2910 PRINTSC;" SUCCESSES"
2970 END
2980 :
2990 REM TEST T$, IS A$ = B$?
3000 IFA$=B$THEN3200
3100 COLOR10
3110 PRINT"FAILURE!! IN ";T$
3120 COLOR3
3130 PRINT"A$=";A$
3140 PRINT"B$=";B$
3150 FC=FC+1:RETURN
3200 PRINT"SUCCESS IN ";T$
3210 SC=SC+1:RETURN
