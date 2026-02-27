test1.elf:     file format elf32-littleriscv


Disassembly of section .text:

00000000 <main>:
0:		02134333	DIV       	x6, x6, x1
4:		02192eb3	MULHSU    	x29, x18, x1
8:		dcb7b913	SLTIU     	x18, x15, 3531
c:		62c0e913	ORI       	x18, x1, 1580
10:		3a55a313	SLTI      	x6, x11, 933
14:		65a1c8e3	BLT       	x3, x26, 1832
18:		d83cf863	BGEU      	x25, x3, 2760
1c:		039d4833	DIV       	x16, x26, x25
20:		342265f3	CSRRSI    	x11, 0x342, 4	# mtval
24:		019c8533	ADD       	x10, x25, x25
28:		03081b33	MULH      	x22, x16, x16
2c:		036631b3	MULHU     	x3, x12, x22
30:		019b5eb3	SRL       	x29, x22, x25
34:		cc51fc93	ANDI      	x25, x3, 3269
38:		5e954b13	XORI      	x22, x10, 1513
3c:		03986b33	REM       	x22, x16, x25
40:		cb987463	BGEU      	x16, x25, 2644
44:		0366f0b3	REMU      	x1, x13, x22
48:		5f6b7313	ANDI      	x6, x22, 1526
4c:		0390fcb3	REMU      	x25, x1, x25
50:		02db0cb3	MUL       	x25, x22, x13
54:		0396e1b3	REM       	x3, x13, x25
58:		01d914b3	SLL       	x9, x18, x29
5c:		01785cb3	SRL       	x25, x16, x23
60:		0391d833	DIVU      	x16, x3, x25
64:		36d0086f	JAL       	x16, 1462
68:		0166ba33	SLTU      	x20, x13, x22
6c:		23187793	ANDI      	x15, x16, 561
70:		026d1533	MULH      	x10, x26, x6
74:		dda00f23	SB        	x26, 3550(x0)
78:		1cdc8b13	ADDI      	x22, x25, 461
7c:		aec1fb13	ANDI      	x22, x3, 2796
80:		94f00a23	SB        	x15, 2388(x0)
84:		1d200223	SB        	x18, 452(x0)
88:		41db5933	SRA       	x18, x22, x29
8c:		90b00323	SB        	x11, 2310(x0)
90:		629006ef	JAL       	x13, 1812
94:		039a00b3	MUL       	x1, x20, x25
98:		2c602023	SW        	x6, 704(x0)
9c:		0237ccb3	DIV       	x25, x15, x3
a0:		c0106973	CSRRSI    	x18, 0xc01, 0	# mtime
a4:		3424acf3	CSRRS     	x25, 0x342, x9	# mtval
a8:		9c387913	ANDI      	x18, x16, 2499
ac:		021b2333	MULHSU    	x6, x22, x1
b0:		039b4b33	DIV       	x22, x22, x25
b4:		30283bf3	CSRRC     	x23, 0x302, x16	# mdeleg
b8:		01dbe333	OR        	x6, x23, x29
bc:		005b5b13	SRLI      	x22, x22, 5
c0:		22484913	XORI      	x18, x16, 548
c4:		342b3873	CSRRC     	x16, 0x342, x22	# mtval
c8:		03acc333	DIV       	x6, x25, x26
cc:		029e5797	AUIPC     	x15, 10725
d0:		40dbd193	SRAI      	x3, x23, 13
d4:		0107aa33	SLT       	x20, x15, x16
d8:		90604e83	LBU       	x29, 2310(x0)
dc:		416a5a33	SRA       	x20, x20, x22
e0:		2bb67913	ANDI      	x18, x12, 699
e4:		c01d75f3	CSRRCI    	x11, 0xc01, 26	# mtime
e8:		00c31a13	SLLI      	x20, x6, 12
ec:		01d4d693	SRLI      	x13, x9, 29
f0:		6b390693	ADDI      	x13, x18, 1715
f4:		029cbcb3	MULHU     	x25, x25, x9
f8:		02cb4bb3	DIV       	x23, x22, x12
fc:		08986663	BLTU      	x16, x9, 70
100:		66cc86e3	BEQ       	x25, x12, 1846
104:		01abca33	XOR       	x20, x23, x26
108:		01935c93	SRLI      	x25, x6, 25
10c:		7e80096f	JAL       	x18, 1012
110:		01031eb3	SLL       	x29, x6, x16
114:		2c005303	LHU       	x6, 704(x0)
118:		0160f0e3	BGEU      	x1, x22, 1024
11c:		90a00623	SB        	x10, 2316(x0)
120:		03996333	REM       	x6, x18, x25
124:		41b6db13	SRAI      	x22, x13, 27
128:		2c004b83	LBU       	x23, 704(x0)
12c:		2c000a03	LB        	x20, 704(x0)
130:		012360b3	OR        	x1, x6, x18
134:		344664f3	CSRRSI    	x9, 0x344, 12	# mtval
138:		34093bf3	CSRRC     	x23, 0x340, x18	# mscratch
13c:		01f69d13	SLLI      	x26, x13, 31
140:		02d79333	MULH      	x6, x15, x13
144:		001b15b3	SLL       	x11, x22, x1
148:		019ec1b3	XOR       	x3, x29, x25
14c:		eb201123	SH        	x18, 3746(x0)
150:		234eed13	ORI       	x26, x29, 564
154:		45a1da63	BGE       	x3, x26, 554
158:		e8600923	SB        	x6, 3730(x0)
15c:		00d49c93	SLLI      	x25, x9, 13
160:		dde05b03	LHU       	x22, 3550(x0)
164:		49a530b7	LUI       	x1, 301651
168:		a76cda63	BGE       	x25, x22, 2362
16c:		fe64e0b7	LUI       	x1, 1041998
170:		20301d23	SH        	x3, 538(x0)
174:		90c04903	LBU       	x18, 2316(x0)
178:		0066cb33	XOR       	x22, x13, x6
17c:		fb234263	BLT       	x6, x18, 3026
180:		02d83b33	MULHU     	x22, x16, x13
184:		006ca333	SLT       	x6, x25, x6
188:		1da02b23	SW        	x26, 470(x0)
18c:		f5601923	SH        	x22, 3922(x0)
190:		02991cb3	MULH      	x25, x18, x9
194:		ffd90ae3	BEQ       	x18, x29, 4090
198:		305d6a73	CSRRSI    	x20, 0x305, 26	# mtvec
19c:		d06d01e7	JALR      	x3, x26, 3334
1a0:		3425a1f3	CSRRS     	x3, 0x342, x11	# mcause
1a4:		001b06b3	ADD       	x13, x22, x1
1a8:		15401b6f	JAL       	x22, 2218
1ac:		10102323	SW        	x1, 262(x0)
1b0:		10ac8093	ADDI      	x1, x25, 266
1b4:		f9d90c63	BEQ       	x18, x29, 3020
1b8:		34463d73	CSRRC     	x26, 0x344, x12	# mtval
1bc:		302256f3	CSRRWI    	x13, 0x302, 4	# mdeleg
1c0:		c01d3d73	CSRRC     	x26, 0xc01, x26	# mtime
1c4:		01268cb3	ADD       	x25, x13, x18
1c8:		010b0eb3	ADD       	x29, x22, x16
1cc:		00fd7b33	AND       	x22, x26, x15
1d0:		4100dd33	SRA       	x26, x1, x16
1d4:		f57cf693	ANDI      	x13, x25, 3927
1d8:		010680b3	ADD       	x1, x13, x16
1dc:		c00b3973	CSRRC     	x18, 0xc00, x22	# mcycle
1e0:		01219333	SLL       	x6, x3, x18
1e4:		416c8333	SUB       	x6, x25, x22
1e8:		0061fcb3	AND       	x25, x3, x6
1ec:		930b6193	ORI       	x3, x22, 2352
1f0:		67a02523	SW        	x26, 1642(x0)
1f4:		10602683	LW        	x13, 262(x0)
1f8:		0f870e97	AUIPC     	x29, 63600
1fc:		4a10e063	BLTU      	x1, x1, 592
200:		c54900b7	LUI       	x1, 808080
204:		01b81693	SLLI      	x13, x16, 27
208:		41495bb3	SRA       	x23, x18, x20
20c:		41201b23	SH        	x18, 1046(x0)
210:		4426c313	XORI      	x6, x13, 1090
214:		3008ed73	CSRRSI    	x26, 0x300, 17	# mstatus
218:		33fb3813	SLTIU     	x16, x22, 831
21c:		0300da33	DIVU      	x20, x1, x16
220:		026ce933	REM       	x18, x25, x6
224:		3585d817	AUIPC     	x16, 219229
228:		02c93cb3	MULHU     	x25, x18, x12
22c:		7d5bbd13	SLTIU     	x26, x23, 2005
230:		41d90cb3	SUB       	x25, x18, x29
234:		15a92813	SLTI      	x16, x18, 346
238:		07600023	SB        	x22, 96(x0)
23c:		26f02223	SW        	x15, 612(x0)
240:		019b7533	AND       	x10, x22, x25
244:		e5001323	SH        	x16, 3654(x0)
248:		00f93d33	SLTU      	x26, x18, x15
24c:		2ed01523	SH        	x13, 746(x0)
250:		66a01583	LH        	x11, 1642(x0)
254:		303c9373	CSRRW     	x6, 0x303, x25	# mideleg
258:		016d1cb3	SLL       	x25, x26, x22
25c:		b5d968e3	BLTU      	x18, x29, 3496
260:		0194dd33	SRL       	x26, x9, x25
264:		0002cbb7	LUI       	x23, 44
268:		03dd6533	REM       	x10, x26, x29
26c:		872e8d67	JALR      	x26, x29, 2162
270:		00935833	SRL       	x16, x6, x9
274:		501086e7	JALR      	x13, x1, 1281
278:		1d602c83	LW        	x25, 470(x0)
27c:		039334b3	MULHU     	x9, x6, x25
280:		dfc7fb13	ANDI      	x22, x15, 3580
284:		06002b03	LW        	x22, 96(x0)
288:		85f32813	SLTI      	x16, x6, 2143
28c:		461c82e3	BEQ       	x25, x1, 1586
290:		012c9313	SLLI      	x6, x25, 18
294:		8391f063	BGEU      	x3, x25, 2064
298:		06002803	LW        	x16, 96(x0)
29c:		0297f0b3	REMU      	x1, x15, x9
2a0:		2c005083	LHU       	x1, 704(x0)
2a4:		c0131673	CSRRW     	x12, 0xc01, x6	# mtime
2a8:		0126d4b3	SRL       	x9, x13, x18
2ac:		28a9db17	AUIPC     	x22, 166557
2b0:		2ea00b03	LB        	x22, 746(x0)
2b4:		00a87933	AND       	x18, x16, x10
2b8:		66f7db17	AUIPC     	x22, 421757
2bc:		ff0a1c97	AUIPC     	x25, 1044641
2c0:		00495813	SRLI      	x16, x18, 4
2c4:		0101fbb3	AND       	x23, x3, x16
2c8:		0391d533	DIVU      	x10, x3, x25
2cc:		00f69333	SLL       	x6, x13, x15
2d0:		0211e833	REM       	x16, x3, x1
2d4:		40c35b13	SRAI      	x22, x6, 12
2d8:		b1201223	SH        	x18, 2820(x0)
2dc:		00992eb3	SLT       	x29, x18, x9
2e0:		3ff1d817	AUIPC     	x16, 261917
2e4:		032edcb3	DIVU      	x25, x29, x18
2e8:		02acc4b3	DIV       	x9, x25, x10
2ec:		01f5d193	SRLI      	x3, x11, 31
2f0:		67211c97	AUIPC     	x25, 422417
2f4:		712cb813	SLTIU     	x16, x25, 1810
2f8:		92cbda63	BGE       	x23, x12, 2202
2fc:		037c81e7	JALR      	x3, x25, 55
300:		0260f533	REMU      	x10, x1, x6
304:		c7dcca63	BLT       	x25, x29, 2618
308:		50c38cb7	LUI       	x25, 330808
30c:		3012f7f3	CSRRCI    	x15, 0x301, 5	# misa
310:		018b1193	SLLI      	x3, x22, 24
314:		26936b93	ORI       	x23, x6, 617
318:		ddd68967	JALR      	x18, x13, 3549
31c:		45790967	JALR      	x18, x18, 1111
320:		b0400803	LB        	x16, 2820(x0)
324:		3427ebf3	CSRRSI    	x23, 0x342, 15	# mtval
328:		017ca6b3	SLT       	x13, x25, x23
32c:		f6a02b23	SW        	x10, 3958(x0)
330:		300661f3	CSRRSI    	x3, 0x300, 12	# mstatus
334:		41285b93	SRAI      	x23, x16, 18
338:		28961c63	BNE       	x12, x9, 332
33c:		dde02303	LW        	x6, 3550(x0)
340:		40285a13	SRAI      	x20, x16, 2
344:		ea202483	LW        	x9, 3746(x0)
348:		0217fcb3	REMU      	x25, x15, x1
34c:		03acdeb3	DIVU      	x29, x25, x26
350:		6f74c463	BLT       	x9, x23, 884
354:		d2690ee3	BEQ       	x18, x6, 3742
358:		02d81eb3	MULH      	x29, x16, x13
35c:		90c04683	LBU       	x13, 2316(x0)
360:		f146bd73	CSRRC     	x26, 0xf14, x13	# mhartid
364:		21a01e83	LH        	x29, 538(x0)
368:		0ffeeb13	ORI       	x22, x29, 255
36c:		0217f7b3	REMU      	x15, x15, x1
370:		90600803	LB        	x16, 2310(x0)
374:		63a816e3	BNE       	x16, x26, 1814
378:		a9601e23	SH        	x22, 2716(x0)
37c:		40368533	SUB       	x10, x13, x3
380:		00b1a0b3	SLT       	x1, x3, x11
384:		22102d23	SW        	x1, 570(x0)
388:		039ed633	DIVU      	x12, x29, x25
38c:		0237ceb3	DIV       	x29, x15, x3
390:		c0066973	CSRRSI    	x18, 0xc00, 12	# mcycle
394:		0100ab33	SLT       	x22, x1, x16
398:		0164ab33	SLT       	x22, x9, x22
39c:		51201823	SH        	x18, 1296(x0)
3a0:		342ddb73	CSRRWI    	x22, 0x342, 27	# mtval
3a4:		ddf0cc93	XORI      	x25, x1, 3551
3a8:		4a33a6b7	LUI       	x13, 303930
3ac:		5a3786e3	BEQ       	x15, x3, 1750
3b0:		40948533	SUB       	x10, x9, x9
3b4:		51001583	LH        	x11, 1296(x0)
3b8:		f241f813	ANDI      	x16, x3, 3876
3bc:		09844b37	LUI       	x22, 38980
3c0:		375a6a13	ORI       	x20, x20, 885
3c4:		3f5d2b13	SLTI      	x22, x26, 1013
3c8:		305e9873	CSRRW     	x16, 0x305, x29	# mtvec
3cc:		00769613	SLLI      	x12, x13, 7
3d0:		00db1333	SLL       	x6, x22, x13
3d4:		c00bf5f3	CSRRCI    	x11, 0xc00, 23	# mcycle
3d8:		02631333	MULH      	x6, x6, x6
3dc:		5c308793	ADDI      	x15, x1, 1475
3e0:		01080633	ADD       	x12, x16, x16
3e4:		7f59eeb7	LUI       	x29, 521630
3e8:		0036c6b3	XOR       	x13, x13, x3
3ec:		e4602603	LW        	x12, 3654(x0)
3f0:		45c01cef	JAL       	x25, 2606
3f4:		1ad001ef	JAL       	x3, 1238
3f8:		a61cf913	ANDI      	x18, x25, 2657
3fc:		600d8697	AUIPC     	x13, 393432
400:		66a01b03	LH        	x22, 1642(x0)
404:		00a571b3	AND       	x3, x10, x10
408:		010b7cb3	AND       	x25, x22, x16
40c:		e7a0d6e3	BGE       	x1, x26, 3894
410:		40ed5c93	SRAI      	x25, x26, 14
414:		039b4cb3	DIV       	x25, x22, x25
418:		011b5913	SRLI      	x18, x22, 17
41c:		cdd5e6e3	BLTU      	x11, x29, 3686
420:		90604b03	LBU       	x22, 2310(x0)
424:		b2601b23	SH        	x6, 2870(x0)
428:		02f820b3	MULHSU    	x1, x16, x15
42c:		214b5263	BGE       	x22, x20, 258
430:		03993333	MULHU     	x6, x18, x25
434:		301d2cf3	CSRRS     	x25, 0x301, x26	# misa
438:		c3af6317	AUIPC     	x6, 801526
43c:		73aefe63	BGEU      	x29, x26, 926
440:		03984933	DIV       	x18, x16, x25
444:		9fbcbb13	SLTIU     	x22, x25, 2555
448:		bf766ee3	BLTU      	x12, x23, 3582
44c:		037d40b3	DIV       	x1, x26, x23
450:		0324deb3	DIVU      	x29, x9, x18
454:		2c004803	LBU       	x16, 704(x0)
458:		02b1e833	REM       	x16, x3, x11
45c:		00db6d33	OR        	x26, x22, x13
460:		5f0188e3	BEQ       	x3, x16, 1784
464:		353506e7	JALR      	x13, x10, 851
468:		40bb5693	SRAI      	x13, x22, 11
46c:		db2868e3	BLTU      	x16, x18, 3800
470:		00185813	SRLI      	x16, x16, 1
474:		03637cb3	REMU      	x25, x6, x22
478:		30382b73	CSRRS     	x22, 0x303, x16	# mideleg
47c:		41630b33	SUB       	x22, x6, x22
480:		0e151663	BNE       	x10, x1, 118
484:		b1da4a13	XORI      	x20, x20, 2845
488:		dde00803	LB        	x16, 3550(x0)
48c:		023cdeb3	DIVU      	x29, x25, x3
490:		00fa2cb3	SLT       	x25, x20, x15
494:		27900023	SB        	x25, 608(x0)
498:		b3602e83	LW        	x29, 2870(x0)
49c:		b3602a03	LW        	x20, 2870(x0)
4a0:		014d5cb3	SRL       	x25, x26, x20
4a4:		e4166a63	BLTU      	x12, x1, 2858
4a8:		452850e3	BGE       	x16, x18, 1568
4ac:		416c8eb3	SUB       	x29, x25, x22
4b0:		01985913	SRLI      	x18, x16, 25
4b4:		e6c87813	ANDI      	x16, x16, 3692
4b8:		b3602e83	LW        	x29, 2870(x0)
4bc:		25984c93	XORI      	x25, x16, 601
4c0:		5ff68337	LUI       	x6, 393064
4c4:		013b5313	SRLI      	x6, x22, 19
4c8:		0216beb3	MULHU     	x29, x13, x1
4cc:		e040f813	ANDI      	x16, x1, 3588
4d0:		1d605b03	LHU       	x22, 470(x0)
4d4:		3444a0f3	CSRRS     	x1, 0x344, x9	# mtval
4d8:		03d7b0b3	MULHU     	x1, x15, x29
4dc:		340ef873	CSRRCI    	x16, 0x340, 29	# mscratch
4e0:		cd4ef4e3	BGEU      	x29, x20, 3684
4e4:		01c09093	SLLI      	x1, x1, 28
4e8:		0015c833	XOR       	x16, x11, x1
4ec:		010d3b33	SLTU      	x22, x26, x16
4f0:		11f97093	ANDI      	x1, x18, 287
4f4:		2c001c83	LH        	x25, 704(x0)
4f8:		00d1ecb3	OR        	x25, x3, x13
4fc:		02fec5b3	DIV       	x11, x29, x15
500:		016b0933	ADD       	x18, x22, x22
504:		416684b3	SUB       	x9, x13, x22
508:		00c7d833	SRL       	x16, x15, x12
50c:		41aed5b3	SRA       	x11, x29, x26
510:		92ad70e3	BGEU      	x26, x10, 3216
514:		2906d263	BGE       	x13, x16, 322
518:		017b0d33	ADD       	x26, x22, x23
51c:		0390c1b3	DIV       	x3, x1, x25
520:		02985b33	DIVU      	x22, x16, x9
524:		014825b3	SLT       	x11, x16, x20
528:		28102623	SW        	x1, 652(x0)
52c:		02d4d4b3	DIVU      	x9, x9, x13
530:		fd3b3693	SLTIU     	x13, x22, 4051
534:		f3602323	SW        	x22, 3878(x0)
538:		06004b03	LBU       	x22, 96(x0)
53c:		d3389eb7	LUI       	x29, 865161
540:		01d4c933	XOR       	x18, x9, x29
544:		0161dc93	SRLI      	x25, x3, 22
548:		416c8cb3	SUB       	x25, x25, x22
54c:		be2d5917	AUIPC     	x18, 778965
550:		6d5b3c93	SLTIU     	x25, x22, 1749
554:		610b0b13	ADDI      	x22, x22, 1552
558:		312a7097	AUIPC     	x1, 201383
55c:		1740ba13	SLTIU     	x20, x1, 372
560:		340f6a73	CSRRSI    	x20, 0x340, 30	# mscratch
564:		af40f313	ANDI      	x6, x1, 2804
568:		87d6b313	SLTIU     	x6, x13, 2173
56c:		40e35c93	SRAI      	x25, x6, 14
570:		68f30813	ADDI      	x16, x6, 1679
574:		03957b33	REMU      	x22, x10, x25
578:		3790166f	JAL       	x12, 3516
57c:		fd602823	SW        	x22, 4048(x0)
580:		01292933	SLT       	x18, x18, x18
584:		544d6913	ORI       	x18, x26, 1348
588:		017b11b3	SLL       	x3, x22, x23
58c:		416cd7b3	SRA       	x15, x25, x22
590:		03aeb0b3	MULHU     	x1, x29, x26
594:		295b3813	SLTIU     	x16, x22, 661
598:		00d1d1b3	SRL       	x3, x3, x13
59c:		881604e3	BEQ       	x12, x1, 3140
5a0:		305e91f3	CSRRW     	x3, 0x305, x29	# mtvec
5a4:		0395cd33	DIV       	x26, x11, x25
5a8:		026810b3	MULH      	x1, x16, x6
5ac:		8d236313	ORI       	x6, x6, 2258
5b0:		fea48513	ADDI      	x10, x9, 4074
5b4:		02bb7b33	REMU      	x22, x22, x11
5b8:		f2604e83	LBU       	x29, 3878(x0)
5bc:		012b1d33	SLL       	x26, x22, x18
5c0:		00791d13	SLLI      	x26, x18, 7
5c4:		17900e23	SB        	x25, 380(x0)
5c8:		9da4d4e3	BGE       	x9, x26, 3300
5cc:		f5205d03	LHU       	x26, 3922(x0)
5d0:		019c8633	ADD       	x12, x25, x25
5d4:		e4601503	LH        	x10, 3654(x0)
5d8:		34115973	CSRRWI    	x18, 0x341, 2	# mepc
5dc:		e4f82c93	SLTI      	x25, x16, 3663
5e0:		00134eb3	XOR       	x29, x6, x1
5e4:		001b0d33	ADD       	x26, x22, x1
5e8:		a2ebc817	AUIPC     	x16, 667324
5ec:		01684833	XOR       	x16, x16, x22
5f0:		3004ebf3	CSRRSI    	x23, 0x300, 9	# mstatus
5f4:		3032da73	CSRRWI    	x20, 0x303, 5	# mideleg
5f8:		003cd5b3	SRL       	x11, x25, x3
5fc:		3415eef3	CSRRSI    	x29, 0x341, 11	# mepc
600:		02e1ed17	AUIPC     	x26, 11806
604:		006eb6b3	SLTU      	x13, x29, x6
608:		342536f3	CSRRC     	x13, 0x342, x10	# mcause
60c:		4f5ee693	ORI       	x13, x29, 1269
610:		01191193	SLLI      	x3, x18, 17
614:		417d5913	SRAI      	x18, x26, 23
618:		02feeb33	REM       	x22, x29, x15
61c:		29d90a63	BEQ       	x18, x29, 330
620:		c2602b23	SW        	x6, 3126(x0)
624:		26402903	LW        	x18, 612(x0)
628:		003c8833	ADD       	x16, x25, x3
62c:		2967c6e3	BLT       	x15, x22, 1350
630:		9c384093	XORI      	x1, x16, 2499
634:		01a1a833	SLT       	x16, x3, x26
638:		3ad0156f	JAL       	x10, 3542
63c:		2e3a2593	SLTI      	x11, x20, 739
640:		01279c93	SLLI      	x25, x15, 18
644:		9c1b6493	ORI       	x9, x22, 2497
648:		02318a33	MUL       	x20, x3, x3
64c:		91601823	SH        	x22, 2320(x0)
650:		001910b3	SLL       	x1, x18, x1
654:		90c05083	LHU       	x1, 2316(x0)
658:		021b3333	MULHU     	x6, x22, x1
65c:		00dcfb33	AND       	x22, x25, x13
660:		907c81e7	JALR      	x3, x25, 2311
664:		c001e5f3	CSRRSI    	x11, 0xc00, 3	# mcycle
668:		03dd2cb3	MULHSU    	x25, x26, x29
66c:		64902023	SW        	x9, 1600(x0)
670:		41f5d813	SRAI      	x16, x11, 31
674:		95404b03	LBU       	x22, 2388(x0)
678:		566958e3	BGE       	x18, x6, 1720
67c:		e8b02123	SW        	x11, 3714(x0)
680:		5dd00bef	JAL       	x23, 1774
684:		b0404083	LBU       	x1, 2820(x0)
688:		00d0f833	AND       	x16, x1, x13
68c:		e8b57c93	ANDI      	x25, x10, 3723
690:		34432b73	CSRRS     	x22, 0x344, x6	# mtval
694:		c0147b73	CSRRCI    	x22, 0xc01, 8	# mtime
698:		fe5b0967	JALR      	x18, x22, 4069
69c:		64100723	SB        	x1, 1614(x0)
6a0:		43655ae3	BGE       	x10, x22, 1562
6a4:		3415d873	CSRRWI    	x16, 0x341, 11	# mepc
6a8:		98eb0ee7	JALR      	x29, x22, 2446
6ac:		006cd5b3	SRL       	x11, x25, x6
6b0:		c0119b73	CSRRW     	x22, 0xc01, x3	# mtime
6b4:		a7afcb37	LUI       	x22, 686844
6b8:		b4f6c8e3	BLT       	x13, x15, 3496
6bc:		1f9ee2e3	BLTU      	x29, x25, 1266
6c0:		009526b3	SLT       	x13, x10, x9
6c4:		4527d663	BGE       	x15, x18, 550
6c8:		c00b1ef3	CSRRW     	x29, 0xc00, x22	# mcycle
6cc:		d7d4dee3	BGE       	x9, x29, 3774
6d0:		00d87b33	AND       	x22, x16, x13
6d4:		41280b33	SUB       	x22, x16, x18
6d8:		0161c5b3	XOR       	x11, x3, x22
6dc:		026cbd33	MULHU     	x26, x25, x6
6e0:		7a6082e3	BEQ       	x1, x6, 2002
6e4:		412c84b3	SUB       	x9, x25, x18
6e8:		209bfc93	ANDI      	x25, x23, 521
6ec:		021eaeb3	MULHSU    	x29, x29, x1
6f0:		01dc9793	SLLI      	x15, x25, 29
6f4:		02c0b633	MULHU     	x12, x1, x12
6f8:		01a86833	OR        	x16, x16, x26
6fc:		9b21c663	BLT       	x3, x18, 2262
700:		871f5817	AUIPC     	x16, 553461
704:		03a616b3	MULH      	x13, x12, x26
708:		001ceb33	OR        	x22, x25, x1
70c:		032b1533	MULH      	x10, x22, x18
710:		0107ab33	SLT       	x22, x15, x16
714:		83730663	BEQ       	x6, x23, 2070
718:		64e04783	LBU       	x15, 1614(x0)
71c:		030b00b3	MUL       	x1, x22, x16
720:		91001a03	LH        	x20, 2320(x0)
724:		0a102223	SW        	x1, 164(x0)
728:		02fe9933	MULH      	x18, x29, x15
72c:		00682cb3	SLT       	x25, x16, x6
730:		0396c533	DIV       	x10, x13, x25
734:		001ed333	SRL       	x6, x29, x1
738:		389a0663	BEQ       	x20, x9, 454
73c:		0324dd33	DIVU      	x26, x9, x18
740:		64e00803	LB        	x16, 1614(x0)
744:		0176ab33	SLT       	x22, x13, x23
748:		64002b83	LW        	x23, 1600(x0)
74c:		00b1fcb3	AND       	x25, x3, x11
750:		82649c63	BNE       	x9, x6, 2076
754:		016b5313	SRLI      	x6, x22, 22
758:		3444e873	CSRRSI    	x16, 0x344, 9	# mtval
75c:		3ea66a63	BLTU      	x12, x10, 506
760:		00b344b3	XOR       	x9, x6, x11
764:		2f9b7663	BGEU      	x22, x25, 374
768:		90600803	LB        	x16, 2310(x0)
76c:		bda02e23	SW        	x26, 3036(x0)
770:		e8202303	LW        	x6, 3714(x0)
774:		3bd0096f	JAL       	x18, 1502
778:		410b5c93	SRAI      	x25, x22, 16
77c:		01049333	SLL       	x6, x9, x16
780:		e4602083	LW        	x1, 3654(x0)
784:		3b156813	ORI       	x16, x10, 945
788:		f14d2b73	CSRRS     	x22, 0xf14, x26	# mhartid
78c:		6f7b6e93	ORI       	x29, x22, 1783
790:		bb75da63	BGE       	x11, x23, 2522
794:		0064a4b3	SLT       	x9, x9, x6
798:		02becb33	DIV       	x22, x29, x11
79c:		ec100a23	SB        	x1, 3796(x0)
7a0:		c4eeec93	ORI       	x25, x29, 3150
7a4:		9c3d40e3	BLT       	x26, x3, 3296
7a8:		7ec01d6f	JAL       	x26, 3062
7ac:		019814b3	SLL       	x9, x16, x25
7b0:		f141e873	CSRRSI    	x16, 0xf14, 3	# mhartid
7b4:		021bfd33	REMU      	x26, x23, x1
7b8:		403b51b3	SRA       	x3, x22, x3
7bc:		01635d33	SRL       	x26, x6, x22
7c0:		1e301423	SH        	x3, 488(x0)
7c4:		3410f0f3	CSRRCI    	x1, 0x341, 1	# mepc
7c8:		012850b3	SRL       	x1, x16, x18
7cc:		bf202223	SW        	x18, 3044(x0)
7d0:		039b1533	MULH      	x10, x22, x25
7d4:		23901923	SH        	x25, 562(x0)
7d8:		7fb68967	JALR      	x18, x13, 2043
7dc:		9aa86a63	BLTU      	x16, x10, 2266
7e0:		341bb4f3	CSRRC     	x9, 0x341, x23	# mepc
7e4:		01535313	SRLI      	x6, x6, 21
7e8:		342e9bf3	CSRRW     	x23, 0x342, x29	# mtval
7ec:		be401b83	LH        	x23, 3044(x0)
7f0:		556344e3	BLT       	x6, x22, 1700
7f4:		c0153373	CSRRC     	x6, 0xc01, x10	# mtime
7f8:		e110ab93	SLTI      	x23, x1, 3601
7fc:		029cfb33	REMU      	x22, x25, x9
800:		039cfcb3	REMU      	x25, x25, x25
804:		00b917b3	SLL       	x15, x18, x11
808:		f8082813	SLTI      	x16, x16, 3968
80c:		4aa01523	SH        	x10, 1194(x0)
810:		01255b13	SRLI      	x22, x10, 18
814:		0a0014ef	JAL       	x9, 2128
818:		c3602583	LW        	x11, 3126(x0)
81c:		f14b10f3	CSRRW     	x1, 0xf14, x22	# mhartid
820:		30461ef3	CSRRW     	x29, 0x304, x12	# mie
824:		40de8b33	SUB       	x22, x29, x13
828:		30305973	CSRRWI    	x18, 0x303, 0	# mideleg
82c:		03a4c6b3	DIV       	x13, x9, x26
830:		01ad1a13	SLLI      	x20, x26, 26
834:		72b6da63	BGE       	x13, x11, 922
838:		03018533	MUL       	x10, x3, x16
83c:		c96514e3	BNE       	x10, x22, 3652
840:		dde00803	LB        	x16, 3550(x0)
844:		01982833	SLT       	x16, x16, x25
848:		9c208093	ADDI      	x1, x1, 2498
84c:		5bea2513	SLTI      	x10, x20, 1470
850:		74902723	SW        	x9, 1870(x0)
854:		266b6863	BLTU      	x22, x6, 312
858:		64004503	LBU       	x10, 1600(x0)
85c:		401c8333	SUB       	x6, x25, x1
860:		f14b7973	CSRRCI    	x18, 0xf14, 22	# mhartid
864:		030b8333	MUL       	x6, x23, x16
868:		1c404603	LBU       	x12, 452(x0)
86c:		6c1d7863	BGEU      	x26, x1, 872
870:		03a1ceb3	DIV       	x29, x3, x26
874:		51966ee3	BLTU      	x12, x25, 1678
878:		301d6ef3	CSRRSI    	x29, 0x301, 26	# misa
87c:		4d002523	SW        	x16, 1226(x0)
880:		190bc4e3	BLT       	x23, x16, 1220
884:		f3600923	SB        	x22, 3890(x0)
888:		00d877b3	AND       	x15, x16, x13
88c:		9aa01023	SH        	x10, 2464(x0)
890:		11d48063	BEQ       	x9, x29, 128
894:		03068333	MUL       	x6, x13, x16
898:		301e9cf3	CSRRW     	x25, 0x301, x29	# misa
89c:		a9c84c93	XORI      	x25, x16, 2716
8a0:		c01fd573	CSRRWI    	x10, 0xc01, 31	# mtime
8a4:		030ced33	REM       	x26, x25, x16
8a8:		41a58d33	SUB       	x26, x11, x26
8ac:		27200623	SB        	x18, 620(x0)
8b0:		0237eb33	REM       	x22, x15, x3
8b4:		4a400cef	JAL       	x25, 594
8b8:		0164fd33	AND       	x26, x9, x22
8bc:		037bed33	REM       	x26, x23, x23
8c0:		40dcd493	SRAI      	x9, x25, 13
8c4:		29001523	SH        	x16, 650(x0)
8c8:		01a94833	XOR       	x16, x18, x26
8cc:		a9c01803	LH        	x16, 2716(x0)
8d0:		017d5913	SRLI      	x18, x26, 23
8d4:		01265cb3	SRL       	x25, x12, x18
8d8:		924eb613	SLTIU     	x12, x29, 2340
8dc:		40fc8a33	SUB       	x20, x25, x15
8e0:		0a404503	LBU       	x10, 164(x0)
8e4:		66a05583	LHU       	x11, 1642(x0)
8e8:		019304b3	ADD       	x9, x6, x25
8ec:		009340b3	XOR       	x1, x6, x9
8f0:		41090d33	SUB       	x26, x18, x16
8f4:		00be80b3	ADD       	x1, x29, x11
8f8:		183bcce3	BLT       	x23, x3, 1228
8fc:		037306b3	MUL       	x13, x6, x23
900:		411d5513	SRAI      	x10, x26, 17
904:		61ab3e93	SLTIU     	x29, x22, 1562
908:		0036bb33	SLTU      	x22, x13, x3
90c:		029b7533	REMU      	x10, x22, x9
910:		00b0ccb3	XOR       	x25, x1, x11
914:		036be0b3	REM       	x1, x23, x22
918:		019b15b3	SLL       	x11, x22, x25
91c:		78981c63	BNE       	x16, x9, 972
920:		983564e3	BLTU      	x10, x3, 3268
924:		01d37833	AND       	x16, x6, x29
928:		0016a6b3	SLT       	x13, x13, x1
92c:		b7a48a67	JALR      	x20, x9, 2938
930:		03733eb3	MULHU     	x29, x6, x23
934:		6c6cee63	BLTU      	x25, x6, 878
938:		9fa00f23	SB        	x26, 2558(x0)
93c:		01635933	SRL       	x18, x6, x22
940:		8f901e23	SH        	x25, 2300(x0)
944:		08d1fb13	ANDI      	x22, x3, 141
948:		300e5b73	CSRRWI    	x22, 0x300, 28	# mstatus
94c:		6bbea913	SLTI      	x18, x29, 1723
950:		023d46b3	DIV       	x13, x26, x3
954:		04108867	JALR      	x16, x1, 65
958:		17c02483	LW        	x9, 380(x0)
95c:		34096373	CSRRSI    	x6, 0x340, 18	# mscratch
960:		3b101d6f	JAL       	x26, 3544
964:		401cdcb3	SRA       	x25, x25, x1
968:		341b3a73	CSRRC     	x20, 0x341, x22	# mepc
96c:		aea08b17	AUIPC     	x22, 715272
970:		01681a33	SLL       	x20, x16, x22
974:		9d602723	SW        	x22, 2510(x0)
978:		c1d56ce3	BLTU      	x10, x29, 3596
97c:		014d31b3	SLTU      	x3, x26, x20
980:		f166e613	ORI       	x12, x13, 3862
984:		49787c93	ANDI      	x25, x16, 1175
988:		01cbd513	SRLI      	x10, x23, 28
98c:		012ebbb3	SLTU      	x23, x29, x18
990:		0191bb33	SLTU      	x22, x3, x25
994:		28c00b83	LB        	x23, 652(x0)
998:		e9202d03	LW        	x26, 3730(x0)
99c:		4aa02b03	LW        	x22, 1194(x0)
9a0:		014cebb3	OR        	x23, x25, x20
9a4:		0125c933	XOR       	x18, x11, x18
9a8:		012916b3	SLL       	x13, x18, x18
9ac:		1950f193	ANDI      	x3, x1, 405
9b0:		0320ccb3	DIV       	x25, x1, x18
9b4:		2ea05c83	LHU       	x25, 746(x0)
9b8:		003b4b33	XOR       	x22, x22, x3
9bc:		51d92193	SLTI      	x3, x18, 1309
9c0:		039a6b33	REM       	x22, x20, x25
9c4:		d8c00823	SB        	x12, 3472(x0)
9c8:		d17c7837	LUI       	x16, 858055
9cc:		003bdd33	SRL       	x26, x23, x3
9d0:		4a1db497	AUIPC     	x9, 303579
9d4:		21a02603	LW        	x12, 538(x0)
9d8:		012324b3	SLT       	x9, x6, x18
9dc:		66a01803	LH        	x16, 1642(x0)
9e0:		c007e973	CSRRSI    	x18, 0xc00, 15	# mcycle
9e4:		029b61b3	REM       	x3, x22, x9
9e8:		029e9cb3	MULH      	x25, x29, x9
9ec:		b90a62e3	BLTU      	x20, x16, 3522
9f0:		0041f693	ANDI      	x13, x3, 4
9f4:		b6bcf263	BGEU      	x25, x11, 2482
9f8:		3004a6f3	CSRRS     	x13, 0x300, x9	# mstatus
9fc:		a9b4f913	ANDI      	x18, x9, 2715
a00:		1e300123	SB        	x3, 482(x0)
a04:		03db7bb3	REMU      	x23, x22, x29
a08:		030ebd33	MULHU     	x26, x29, x16
a0c:		c6a02123	SW        	x10, 3170(x0)
a10:		03db1b33	MULH      	x22, x22, x29
a14:		3031b373	CSRRC     	x6, 0x303, x3	# mideleg
a18:		03d0b933	MULHU     	x18, x1, x29
a1c:		41985333	SRA       	x6, x16, x25
a20:		03dce6b3	REM       	x13, x25, x29
a24:		fe233493	SLTIU     	x9, x6, 4066
a28:		e8201083	LH        	x1, 3714(x0)
a2c:		d71b2b13	SLTI      	x22, x22, 3441
a30:		de6b46e3	BLT       	x22, x6, 3830
a34:		340b95f3	CSRRW     	x11, 0x340, x23	# mscratch
a38:		300f51f3	CSRRWI    	x3, 0x300, 30	# mstatus
a3c:		92db6663	BLTU      	x22, x13, 2198
a40:		02d31533	MULH      	x10, x6, x13
a44:		3364e493	ORI       	x9, x9, 822
a48:		03abab33	MULHSU    	x22, x23, x26
a4c:		10601683	LH        	x13, 262(x0)
a50:		03709633	MULH      	x12, x1, x23
a54:		41980cb3	SUB       	x25, x16, x25
a58:		01219cb3	SLL       	x25, x3, x18
a5c:		410ed193	SRAI      	x3, x29, 16
a60:		02d30cb3	MUL       	x25, x6, x13
a64:		03696b33	REM       	x22, x18, x22
a68:		0341d933	DIVU      	x18, x3, x20
a6c:		010cfcb3	AND       	x25, x25, x16
a70:		03637b33	REMU      	x22, x6, x22
a74:		17f08493	ADDI      	x9, x1, 383
a78:		c00b2b73	CSRRS     	x22, 0xc00, x22	# mcycle
a7c:		25000b6f	JAL       	x22, 296
a80:		026c9b33	MULH      	x22, x25, x6
a84:		00c97b33	AND       	x22, x18, x12
a88:		40150d33	SUB       	x26, x10, x1
a8c:		f7601e83	LH        	x29, 3958(x0)
a90:		1c405c83	LHU       	x25, 452(x0)
a94:		3425d973	CSRRWI    	x18, 0x342, 11	# mcause
a98:		0d6cfb13	ANDI      	x22, x25, 214
a9c:		006c8333	ADD       	x6, x25, x6
aa0:		416bdcb3	SRA       	x25, x23, x22
aa4:		00819c93	SLLI      	x25, x3, 8
aa8:		c0d0e2e3	BLTU      	x1, x13, 3586
aac:		01a0c933	XOR       	x18, x1, x26
ab0:		48ee8613	ADDI      	x12, x29, 1166
ab4:		009c9eb3	SLL       	x29, x25, x9
ab8:		3049f0f3	CSRRCI    	x1, 0x304, 19	# mie
abc:		ebb97813	ANDI      	x16, x18, 3771
ac0:		2aae9463	BNE       	x29, x10, 340
ac4:		ea201783	LH        	x15, 3746(x0)
ac8:		a1901c23	SH        	x25, 2584(x0)
acc:		0120eeb3	OR        	x29, x1, x18
ad0:		3011e7f3	CSRRSI    	x15, 0x301, 3	# misa
ad4:		41708833	SUB       	x16, x1, x23
ad8:		06348567	JALR      	x10, x9, 99
adc:		3f2b7093	ANDI      	x1, x22, 1010
ae0:		79602f23	SW        	x22, 1950(x0)
ae4:		54f01323	SH        	x15, 1350(x0)
ae8:		b6be9463	BNE       	x29, x11, 2484
aec:		1a1cd4e3	BGE       	x25, x1, 1236
af0:		2057ad13	SLTI      	x26, x15, 517
af4:		691b6b93	ORI       	x23, x22, 1681
af8:		0361e833	REM       	x16, x3, x22
afc:		3417d4f3	CSRRWI    	x9, 0x341, 15	# mepc
b00:		7e8ea193	SLTI      	x3, x29, 2024
b04:		f14ae6f3	CSRRSI    	x13, 0xf14, 21	# mhartid
b08:		362a7b17	AUIPC     	x22, 221863
b0c:		01009633	SLL       	x12, x1, x16
b10:		f14f51f3	CSRRWI    	x3, 0xf14, 30	# mhartid
b14:		5df68e93	ADDI      	x29, x13, 1503
b18:		341c9873	CSRRW     	x16, 0x341, x25	# mepc
b1c:		c64b4493	XORI      	x9, x22, 3172
b20:		036cf833	REMU      	x16, x25, x22
b24:		340e9ef3	CSRRW     	x29, 0x340, x29	# mscratch
b28:		39cb0693	ADDI      	x13, x22, 924
b2c:		305a66f3	CSRRSI    	x13, 0x305, 20	# mtvec
b30:		02a49833	MULH      	x16, x9, x10
b34:		55b1ee93	ORI       	x29, x3, 1371
b38:		136bc6e3	BLT       	x23, x22, 1174
b3c:		01ab1d13	SLLI      	x26, x22, 26
b40:		d1001c23	SH        	x16, 3352(x0)
b44:		3036fd73	CSRRCI    	x26, 0x303, 13	# mideleg
b48:		034b4b33	DIV       	x22, x22, x20
b4c:		64e02e83	LW        	x29, 1614(x0)
b50:		4591a913	SLTI      	x18, x3, 1113
b54:		27356813	ORI       	x16, x10, 627
b58:		016b5b93	SRLI      	x23, x22, 22
b5c:		80b4eae3	BLTU      	x9, x11, 3082
b60:		021b2933	MULHSU    	x18, x22, x1
b64:		932a3913	SLTIU     	x18, x20, 2354
b68:		090d0063	BEQ       	x26, x16, 64
b6c:		69078063	BEQ       	x15, x16, 832
b70:		305af973	CSRRCI    	x18, 0x305, 21	# mtvec
b74:		15a308e3	BEQ       	x6, x26, 1192
b78:		001695b3	SLL       	x11, x13, x1
b7c:		dde01b03	LH        	x22, 3550(x0)
b80:		029677b3	REMU      	x15, x12, x9
b84:		017b1693	SLLI      	x13, x22, 23
b88:		45731463	BNE       	x6, x23, 548
b8c:		9a430367	JALR      	x6, x6, 2468
b90:		02dd1d33	MULH      	x26, x26, x13
b94:		02383b33	MULHU     	x22, x16, x3
b98:		21900cef	JAL       	x25, 1292
b9c:		30105b73	CSRRWI    	x22, 0x301, 0	# misa
ba0:		40b6d913	SRAI      	x18, x13, 11
ba4:		27600023	SB        	x22, 608(x0)
ba8:		7f80156f	JAL       	x10, 3068
bac:		41d950b3	SRA       	x1, x18, x29
bb0:		039684b3	MUL       	x9, x13, x25
bb4:		a3186693	ORI       	x13, x16, 2609
bb8:		7f801cef	JAL       	x25, 3068
bbc:		40d85b33	SRA       	x22, x16, x13
bc0:		012b1333	SLL       	x6, x22, x18
bc4:		a0391463	BNE       	x18, x3, 2308
bc8:		a564e863	BLTU      	x9, x22, 2344
bcc:		64e02083	LW        	x1, 1614(x0)
bd0:		5e6554e3	BGE       	x10, x6, 1780
bd4:		e5066a63	BLTU      	x12, x16, 2858
bd8:		95293193	SLTIU     	x3, x18, 2386
bdc:		00a81b33	SLL       	x22, x16, x10
be0:		5c8b2193	SLTI      	x3, x22, 1480
be4:		d7d84693	XORI      	x13, x16, 3453
be8:		91e7c813	XORI      	x16, x15, 2334
bec:		30552873	CSRRS     	x16, 0x305, x10	# mtvec
bf0:		008b1693	SLLI      	x13, x22, 8
bf4:		50acfd13	ANDI      	x26, x25, 1290
bf8:		c16d7e63	BGEU      	x26, x22, 2574
bfc:		037cf5b3	REMU      	x11, x25, x23
c00:		039b3633	MULHU     	x12, x22, x25
c04:		00a06537	LUI       	x10, 2566
c08:		00957533	AND       	x10, x10, x9
c0c:		4196d093	SRAI      	x1, x13, 25
c10:		f14dfb73	CSRRCI    	x22, 0xf14, 27	# mhartid
c14:		c40a07e7	JALR      	x15, x20, 3136
c18:		f1435573	CSRRWI    	x10, 0xf14, 6	# mhartid
c1c:		c010e973	CSRRSI    	x18, 0xc01, 1	# mtime
c20:		00fb1933	SLL       	x18, x22, x15
c24:		1ac5c817	AUIPC     	x16, 109660
c28:		a755ac93	SLTI      	x25, x11, 2677
c2c:		bdd5eee3	BLTU      	x11, x29, 3566
c30:		00ab9d33	SLL       	x26, x23, x10
c34:		00d850b3	SRL       	x1, x16, x13
c38:		0177d793	SRLI      	x15, x15, 23
c3c:		f7602483	LW        	x9, 3958(x0)
c40:		01687cb3	AND       	x25, x16, x22
c44:		34437573	CSRRCI    	x10, 0x344, 6	# mtval
c48:		b5a5ec63	BLTU      	x11, x26, 2476
c4c:		c4a90613	ADDI      	x12, x18, 3146
c50:		01aa56b3	SRL       	x13, x20, x26
c54:		00d7cb33	XOR       	x22, x15, x13
c58:		e8202e83	LW        	x29, 3714(x0)
c5c:		d35ea313	SLTI      	x6, x29, 3381
c60:		3008db73	CSRRWI    	x22, 0x300, 17	# mstatus
c64:		e8a7cae3	BLT       	x15, x10, 3914
c68:		35901323	SH        	x25, 838(x0)
c6c:		303f60f3	CSRRSI    	x1, 0x303, 30	# mideleg
c70:		3416bcf3	CSRRC     	x25, 0x341, x13	# mepc
c74:		017b1813	SLLI      	x16, x22, 23
c78:		abbb4313	XORI      	x6, x22, 2747
c7c:		40bcd793	SRAI      	x15, x25, 11
c80:		01431333	SLL       	x6, x6, x20
c84:		4b9cab13	SLTI      	x22, x25, 1209
c88:		01db2bb3	SLT       	x23, x22, x29
c8c:		bf94e8e3	BLTU      	x9, x25, 3576
c90:		00949833	SLL       	x16, x9, x9
c94:		6c902223	SW        	x9, 1732(x0)
c98:		41ab50b3	SRA       	x1, x22, x26
c9c:		016b8b33	ADD       	x22, x23, x22
ca0:		45401cef	JAL       	x25, 2602
ca4:		2f97fa63	BGEU      	x15, x25, 378
ca8:		004b1513	SLLI      	x10, x22, 4
cac:		ae85c193	XORI      	x3, x11, 2792
cb0:		fd002903	LW        	x18, 4048(x0)
cb4:		da290d67	JALR      	x26, x18, 3490
cb8:		74e00d03	LB        	x26, 1870(x0)
cbc:		2c000d03	LB        	x26, 704(x0)
cc0:		74e01583	LH        	x11, 1870(x0)
cc4:		91001483	LH        	x9, 2320(x0)
cc8:		52b97a63	BGEU      	x18, x11, 666
ccc:		bf579eb7	LUI       	x29, 783737
cd0:		03ac9eb3	MULH      	x29, x25, x26
cd4:		017cd633	SRL       	x12, x25, x23
cd8:		41f55d13	SRAI      	x26, x10, 31
cdc:		300b5873	CSRRWI    	x16, 0x300, 22	# mstatus
ce0:		029975b3	REMU      	x11, x18, x9
ce4:		006301b3	ADD       	x3, x6, x6
ce8:		00581493	SLLI      	x9, x16, 5
cec:		0b232913	SLTI      	x18, x6, 178
cf0:		40350bb3	SUB       	x23, x10, x3
cf4:		4030d833	SRA       	x16, x1, x3
cf8:		41db5533	SRA       	x10, x22, x29
cfc:		dde02183	LW        	x3, 3550(x0)
d00:		00d1ad33	SLT       	x26, x3, x13
d04:		302adcf3	CSRRWI    	x25, 0x302, 21	# mdeleg
d08:		0235f7b3	REMU      	x15, x11, x3
d0c:		00a5a1b3	SLT       	x3, x11, x10
d10:		0211f633	REMU      	x12, x3, x1
d14:		00a0e5b3	OR        	x11, x1, x10
d18:		0166d833	SRL       	x16, x13, x22
d1c:		c009d673	CSRRWI    	x12, 0xc00, 19	# mcycle
d20:		026b1bb3	MULH      	x23, x22, x6
d24:		037cfd33	REMU      	x26, x25, x23
d28:		859d6a63	BLTU      	x26, x25, 2090
d2c:		00acf333	AND       	x6, x25, x10
d30:		039be333	REM       	x6, x23, x25
d34:		3444b4f3	CSRRC     	x9, 0x344, x9	# mtval
d38:		342ba873	CSRRS     	x16, 0x342, x23	# mtval
d3c:		4f50096f	JAL       	x18, 1658
d40:		c1cec693	XORI      	x13, x29, 3100
d44:		66a01b03	LH        	x22, 1642(x0)
d48:		1143c6b7	LUI       	x13, 70716
d4c:		ef6d12e3	BNE       	x26, x22, 3954
d50:		65900523	SB        	x25, 1610(x0)
d54:		42602a23	SW        	x6, 1076(x0)
d58:		00962333	SLT       	x6, x12, x9
d5c:		beb6ab13	SLTI      	x22, x13, 3051
d60:		023b4933	DIV       	x18, x22, x3
d64:		8b051863	BNE       	x10, x16, 2136
d68:		30231b73	CSRRW     	x22, 0x302, x6	# mdeleg
d6c:		01c81593	SLLI      	x11, x16, 28
d70:		51001303	LH        	x6, 1296(x0)
d74:		01d810b3	SLL       	x1, x16, x29
d78:		01a86b33	OR        	x22, x16, x26
d7c:		02db1533	MULH      	x10, x22, x13
d80:		01d6c1b3	XOR       	x3, x13, x29
d84:		300a1873	CSRRW     	x16, 0x300, x20	# mstatus
d88:		2c000a03	LB        	x20, 704(x0)
d8c:		304837f3	CSRRC     	x15, 0x304, x16	# mie
d90:		02f7db33	DIVU      	x22, x15, x15
d94:		036be1b3	REM       	x3, x23, x22
d98:		40b80cb3	SUB       	x25, x16, x11
d9c:		029cd5b3	DIVU      	x11, x25, x9
da0:		1dd00423	SB        	x29, 456(x0)
da4:		7a6370e3	BGEU      	x6, x6, 2000
da8:		01d67d33	AND       	x26, x12, x29
dac:		003b7eb3	AND       	x29, x22, x3
db0:		abf4f493	ANDI      	x9, x9, 2751
db4:		72708693	ADDI      	x13, x1, 1831
db8:		403d0cb3	SUB       	x25, x26, x3
dbc:		023cbcb3	MULHU     	x25, x25, x3
dc0:		02931cb3	MULH      	x25, x6, x9
dc4:		41c4d593	SRAI      	x11, x9, 28
dc8:		0214cb33	DIV       	x22, x9, x1
dcc:		03294833	DIV       	x16, x18, x18
dd0:		c00276f3	CSRRCI    	x13, 0xc00, 4	# mcycle
dd4:		4101d6b3	SRA       	x13, x3, x16
dd8:		0390fb33	REMU      	x22, x1, x25
ddc:		03265b33	DIVU      	x22, x12, x18
de0:		19a0f913	ANDI      	x18, x1, 410
de4:		9ce01e83	LH        	x29, 2510(x0)
de8:		014bd313	SRLI      	x6, x23, 20
dec:		39601a23	SH        	x22, 916(x0)
df0:		779ce6e3	BLTU      	x25, x25, 1974
df4:		a5002023	SW        	x16, 2624(x0)
df8:		c019dcf3	CSRRWI    	x25, 0xc01, 19	# mtime
dfc:		2ea04783	LBU       	x15, 746(x0)
e00:		304a7ef3	CSRRCI    	x29, 0x304, 20	# mie
e04:		00d1f633	AND       	x12, x3, x13
e08:		03d904b3	MUL       	x9, x18, x29
e0c:		16bee813	ORI       	x16, x29, 363
e10:		00bea333	SLT       	x6, x29, x11
e14:		037d5933	DIVU      	x18, x26, x23
e18:		9c901623	SH        	x9, 2508(x0)
e1c:		34233b73	CSRRC     	x22, 0x342, x6	# mtval
e20:		03649a33	MULH      	x20, x9, x22
e24:		0164a333	SLT       	x6, x9, x22
e28:		34252d73	CSRRS     	x26, 0x342, x10	# mcause
e2c:		300be4f3	CSRRSI    	x9, 0x300, 23	# mstatus
e30:		86f0fb13	ANDI      	x22, x1, 2159
e34:		df132b13	SLTI      	x22, x6, 3569
e38:		303ff4f3	CSRRCI    	x9, 0x303, 31	# mideleg
e3c:		001d2633	SLT       	x12, x26, x1
e40:		64a00303	LB        	x6, 1610(x0)
e44:		93601123	SH        	x22, 2338(x0)
e48:		21c004ef	JAL       	x9, 270
e4c:		4d9844e3	BLT       	x16, x25, 1636
e50:		5086bc93	SLTIU     	x25, x13, 1288
e54:		17c05b03	LHU       	x22, 380(x0)
e58:		01ed5613	SRLI      	x12, x26, 30
e5c:		0a405183	LHU       	x3, 164(x0)
e60:		342b30f3	CSRRC     	x1, 0x342, x22	# mtval
e64:		006961b3	OR        	x3, x18, x6
e68:		4891f8e3	BGEU      	x3, x9, 1608
e6c:		41395d13	SRAI      	x26, x18, 19
e70:		003d04b3	ADD       	x9, x26, x3
e74:		340a36f3	CSRRC     	x13, 0x340, x20	# mscratch
e78:		83486063	BLTU      	x16, x20, 2064
e7c:		34a7b193	SLTIU     	x3, x15, 842
e80:		04bb0b13	ADDI      	x22, x22, 75
e84:		00dd1533	SLL       	x10, x26, x13
e88:		01a68333	ADD       	x6, x13, x26
e8c:		c487ab93	SLTI      	x23, x15, 3144
e90:		2c002803	LW        	x16, 704(x0)
e94:		01d81533	SLL       	x10, x16, x29
e98:		4ca05903	LHU       	x18, 1226(x0)
e9c:		41718933	SUB       	x18, x3, x23
ea0:		17d4ac93	SLTI      	x25, x9, 381
ea4:		c0081b73	CSRRW     	x22, 0xc00, x16	# mcycle
ea8:		03a7f833	REMU      	x16, x15, x26
eac:		92248793	ADDI      	x15, x9, 2338
eb0:		30219973	CSRRW     	x18, 0x302, x3	# mdeleg
eb4:		6a6cbe93	SLTIU     	x29, x25, 1702
eb8:		0390d1b3	DIVU      	x3, x1, x25
ebc:		036d71b3	REMU      	x3, x26, x22
ec0:		64e04183	LBU       	x3, 1614(x0)
ec4:		340a6373	CSRRSI    	x6, 0x340, 20	# mscratch
ec8:		51a0cc63	BLT       	x1, x26, 652
ecc:		00ba0eb3	ADD       	x29, x20, x11
ed0:		01435093	SRLI      	x1, x6, 20
ed4:		2db4a613	SLTI      	x12, x9, 731
ed8:		bd2180e7	JALR      	x1, x3, 3026
edc:		32a364e3	BLTU      	x6, x10, 1428
ee0:		c62cfc93	ANDI      	x25, x25, 3170
ee4:		f3d08d13	ADDI      	x26, x1, 3901
ee8:		6971e8e3	BLTU      	x3, x23, 1864
eec:		1e201803	LH        	x16, 482(x0)
ef0:		0266c833	DIV       	x16, x13, x6
ef4:		e1eeb093	SLTIU     	x1, x29, 3614
ef8:		00a49813	SLLI      	x16, x9, 10
efc:		4475ee93	ORI       	x29, x11, 1095
f00:		d1048263	BEQ       	x9, x16, 2690
f04:		26005083	LHU       	x1, 608(x0)
f08:		01ad1a13	SLLI      	x20, x26, 26
f0c:		001c9cb3	SLL       	x25, x25, x1
f10:		7271fb13	ANDI      	x22, x3, 1831
f14:		ad2b44e3	BLT       	x22, x18, 3428
f18:		3017aef3	CSRRS     	x29, 0x301, x15	# misa
f1c:		d9004083	LBU       	x1, 3472(x0)
f20:		016c8a33	ADD       	x20, x25, x22
f24:		40ab04b3	SUB       	x9, x22, x10
f28:		00119193	SLLI      	x3, x3, 1
f2c:		24f1e863	BLTU      	x3, x15, 296
f30:		b5a7b313	SLTIU     	x6, x15, 2906
f34:		538b2813	SLTI      	x16, x22, 1336
f38:		0294bd33	MULHU     	x26, x9, x9
f3c:		a3aeec93	ORI       	x25, x29, 2618
f40:		f148f6f3	CSRRCI    	x13, 0xf14, 17	# mhartid
f44:		3028e873	CSRRSI    	x16, 0x302, 17	# mdeleg
f48:		06004903	LBU       	x18, 96(x0)
f4c:		c0131673	CSRRW     	x12, 0xc01, x6	# mtime
f50:		01da7cb3	AND       	x25, x20, x29
f54:		7452db97	AUIPC     	x23, 476461
f58:		00dedd13	SRLI      	x26, x29, 13
f5c:		01a85933	SRL       	x18, x16, x26
f60:		344834f3	CSRRC     	x9, 0x344, x16	# mtval
f64:		41fb5d13	SRAI      	x26, x22, 31
f68:		29a01d23	SH        	x26, 666(x0)
f6c:		c0115ef3	CSRRWI    	x29, 0xc01, 2	# mtime
f70:		01961833	SLL       	x16, x12, x25
f74:		41280d33	SUB       	x26, x16, x18
f78:		0061fb33	AND       	x22, x3, x6
f7c:		303c7b73	CSRRCI    	x22, 0x303, 24	# mideleg
f80:		009b1613	SLLI      	x12, x22, 9
f84:		c0db6e63	BLTU      	x22, x13, 2574
f88:		03d97833	REMU      	x16, x18, x29
f8c:		304fed73	CSRRSI    	x26, 0x304, 31	# mie
f90:		c00cbcf3	CSRRC     	x25, 0xc00, x25	# mcycle
f94:		016b0333	ADD       	x6, x22, x22
f98:		40c1d533	SRA       	x10, x3, x12
f9c:		97aeab93	SLTI      	x23, x29, 2426
fa0:		1be32093	SLTI      	x1, x6, 446
fa4:		0520bd13	SLTIU     	x26, x1, 82
fa8:		608b3693	SLTIU     	x13, x22, 1544
fac:		10c000ef	JAL       	x1, 134
fb0:		00d6f833	AND       	x16, x13, x13
fb4:		872c9263	BNE       	x25, x18, 2098
fb8:		0f2b2b13	SLTI      	x22, x22, 242
fbc:		dde04e83	LBU       	x29, 3550(x0)
fc0:		02a300b3	MUL       	x1, x6, x10
fc4:		af50bb13	SLTIU     	x22, x1, 2805
fc8:		340810f3	CSRRW     	x1, 0x340, x16	# mscratch
fcc:		41e95b13	SRAI      	x22, x18, 30
fd0:		03aeeb33	REM       	x22, x29, x26
fd4:		8127cc63	BLT       	x15, x18, 2060
fd8:		badcd4e3	BGE       	x25, x13, 3540
fdc:		b3604d03	LBU       	x26, 2870(x0)
fe0:		80d09ee3	BNE       	x1, x13, 3086
fe4:		0095f333	AND       	x6, x11, x9
fe8:		039edeb3	DIVU      	x29, x29, x25
fec:		1e802c83	LW        	x25, 488(x0)
ff0:		0361cb33	DIV       	x22, x3, x22
ff4:		45dbdbb7	LUI       	x23, 286141
ff8:		9b600623	SB        	x22, 2476(x0)
ffc:		00e59813	SLLI      	x16, x11, 14
