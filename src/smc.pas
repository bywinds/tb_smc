//------------------------------------------------------------------------
// 编译版本    2026/9/9 85011
// 版权所有    Xiaoyang
// 微信        qhmorn
// 策略名称:   SMC_SmartMoneyStrategy
// 策略说明:   基于Smart Money Concepts理论的期货交易策略
// 适用周期:   5分钟、15分钟、1小时
// 适用品种:   国内商品期货（白银、铁矿石、黄金等）
// 版本:       V1.0
//------------------------------------------------------------------------
Params
    Integer UseBarCount(200);
    Integer SwingLength(6);
    Integer SwingLengthAggregation(6);
    Bool JoinConsecutive(False);
    Numeric InpLots(1);
    Numeric InpStopLoss(0.1);
    Numeric InpTakeProfit(0.1);
    Integer InpSlippage(30);
    Numeric InpMaxSpread(50);
    Numeric PreviousHighLowStrength(0.15);
    Numeric BosStrengthAggregation(0.10);
    Numeric BosStrength(0.20);
    Numeric ChochStrength(0.10);
    Numeric ObStrength(0.20);
    Numeric FvgStrength(0.15);
    Numeric LiquidityStrength(0.10);
    Numeric EntryThreshold(0.55);
    Numeric StrongThreshold(0.75);
    Numeric SltpSpread(0.0001);


Vars
    Array<Numeric> Opens;
    Array<Numeric> Highs;
    Array<Numeric> Lows;
    Array<Numeric> Closes;
    Array<Numeric> Volumes;
    Array<Numeric> Times;
    Array<Numeric> LongOpens;
    Array<Numeric> LongHighs;
    Array<Numeric> LongLows;
    Array<Numeric> LongCloses;
    Array<Numeric> LongVolumes;
    Array<Numeric> LongTimes;
    Integer BarCnt;
    Numeric StopLossPrice(0);          // 止损价格
    Numeric TakeProfitPrice(0);        // 止盈价格
    Series<Numeric> ATRs(0);
    Plot plt;



Defs

    Bool CalculateFVG(Array<Numeric> openArr, Array<Numeric> highArr, Array<Numeric> lowArr, Array<Numeric> closeArr, Integer size, Bool joinConsecutive, ArrayRef<Integer> fvg, ArrayRef<Numeric> top, ArrayRef<Numeric> bottom, ArrayRef<Integer> mitigatedIndex)
    {
        SetArraySize(fvg, size, 0);
        SetArraySize(top, size, 0);
        SetArraySize(bottom, size, 0);
        SetArraySize(mitigatedIndex, size, -1);
        Integer i = -1;
        Integer j = -1;
        For i = 1 To size - 2
        {
            If (highArr[i-1] < lowArr[i+1] And closeArr[i] > openArr[i])
            {
                fvg[i] = 1;
                top[i] = lowArr[i+1];
                bottom[i] = highArr[i-1];
            }
            Else If (lowArr[i-1] > highArr[i+1] And closeArr[i] < openArr[i])
            {
                fvg[i] = -1;
                top[i] = lowArr[i-1];
                bottom[i] = highArr[i+1];
            }
        }
        If (joinConsecutive)
        {
            For i = 0 To size - 2
            {
                If (fvg[i] <> 0 And fvg[i] == fvg[i+1])
                {
                    top[i+1] = Max(top[i], top[i+1]);
                    bottom[i+1] = Min(bottom[i], bottom[i+1]);
                    fvg[i] = 0;
                    top[i] = 0;
                    bottom[i] = 0;
                }
            }
        }
        For i = 0 To size - 1
        {
            If (fvg[i] == 0)
            {
                Continue;
            }
            If (fvg[i] == 1)
            {
                For j = i + 2 To size - 1
                {
                    If (lowArr[j] <= top[i])
                    {
                        mitigatedIndex[i] = j;
                        Break;
                    }
                }
            }
            Else If (fvg[i] == -1)
            {
                For j = i + 2 To size - 1
                {
                    If (highArr[j] >= bottom[i])
                    {
                        mitigatedIndex[i] = j;
                        Break;
                    }
                }
            }
        }
        Return True;
    }


    Bool CalculateSwingHighsLows(Array<Numeric> highArr, Array<Numeric> lowArr, Integer size, Integer swing, ArrayRef<Integer> highLows, ArrayRef<Numeric> levels)
    {
        SetArraySize(highLows, size, 0);
        SetArraySize(levels, size, 0);
        Integer i = -1;
        Integer j = -1;
        Integer prev = -1;
        Numeric maxHigh = 0;
        Numeric minLow  = 0;
        Integer first = -1;
        Integer tail  = -1;
        For i = swing - 1 To size - swing - 1
        {
            maxHigh = highArr[i - swing + 1];
            minLow  = lowArr[i - swing + 1];
            
            For j = i - swing + 1 To i + swing
            {
                If (highArr[j] > maxHigh) maxHigh = highArr[j];
                If (lowArr[j] < minLow)   minLow  = lowArr[j];
            }
            If (highArr[i] == maxHigh)
            {
                highLows[i] = 1;
            }
            Else If (lowArr[i] == minLow)
            {
                highLows[i] = -1;
            }
        }
        
        For i = 0 To size - 1
        {
            If (highLows[i] == 0)
            {
                Continue;
            }
            If (prev != -1)
            {
                If (highLows[prev] == 1 And highLows[i] == 1)
                {
                    If (highArr[prev] < highArr[i])
                    {
                        highLows[prev] = 0;
                        prev = i;
                    }
                    Else
                    {
                        highLows[i] = 0;
                    }
                }
                Else If (highLows[prev] == -1 And highLows[i] == -1)
                {
                    If (lowArr[prev] > lowArr[i])
                    {
                        highLows[prev] = 0;
                        prev = i;
                    }
                    Else
                    {
                        highLows[i] = 0;
                    }
                }
                Else
                {
                    prev = i;
                }
            }
            Else
            {
                prev = i;
            }
        }
        
        For i = 0 To size - 1
        {
            If (highLows[i] != 0)
            {
                If (first == -1)
                {
                    first = i;
                }
                Else
                {
                    tail = i;
                }
            }
        }
        If (first != -1 And tail != -1)
        {
            If (highLows[first] == 1)
            {
                highLows[0] = -1;
            }
            Else If (highLows[first] == -1)
            {
                highLows[0] = 1;
            }
            If (highLows[tail] == -1)
            {
                highLows[size - 1] = 1;
            } 
            Else If (highLows[tail] == 1)
            {
                highLows[size - 1] = -1;
            }
        }
        For i = 0 To size - 1
        {
            If (highLows[i] == 1)
            {
                levels[i] = highArr[i];
            }
            Else If (highLows[i] == -1)
            {
                levels[i] = lowArr[i];
            }
            Else
            {
                levels[i] = 0;
            }  
        }   
        Return True;
    }


    Bool CalculateBosChoch(Array<Numeric> highArr, Array<Numeric> lowArr, Array<Numeric> closeArr, Integer size, Array<Integer> highLows, Array<Numeric> levels, Bool closeBreak, ArrayRef<Integer> bos, ArrayRef<Integer> choch, ArrayRef<Numeric> level, ArrayRef<Integer> broken)
    {
        SetArraySize(bos, size, 0);
        SetArraySize(choch, size, 0);
        SetArraySize(level, size, 0);
        SetArraySize(broken, size, -1);
        Integer i = -1;
        Integer j = -1;
        Integer k  = -1;

        Array<Integer>    lastPositions;
        Array<Numeric>    levelOrder;
        Array<Integer>    highLowOrder;
        For i = 0 To size - 1
        {
            Integer hl = highLows[i];
            If(hl == 0)
            {
                continue;
            }
            Integer sz = GetArraySize(levelOrder);
            ArrayPushBack(highLowOrder, hl);
            ArrayPushBack(levelOrder, levels[i]);

            Integer m = sz + 1;
            If(m >= 4)
            {
                Integer L1 = m - 4;
                Integer L2 = m - 3;
                Integer L3 = m - 2;
                Integer L4 = m - 1;
                Integer nlp    = GetArraySize(lastPositions);
                Integer target = lastPositions[nlp - 2];

                Bool isBullBOS =
                    (highLowOrder[L1] == -1 And highLowOrder[L2] ==  1 And
                     highLowOrder[L3] == -1 And highLowOrder[L4] ==  1 And
                     levelOrder[L1] < levelOrder[L3] And
                     levelOrder[L3] < levelOrder[L2] And
                     levelOrder[L2] < levelOrder[L4]);

                bos[target]   = IIF(isBullBOS, 1, 0);
                level[target] = IIF(bos[target] != 0, levelOrder[L2], 0);

                Bool isBearBOS =
                    (highLowOrder[L1] ==  1 And highLowOrder[L2] == -1 And
                     highLowOrder[L3] ==  1 And highLowOrder[L4] == -1 And
                     levelOrder[L1] > levelOrder[L3] And
                     levelOrder[L3] > levelOrder[L2] And
                     levelOrder[L2] > levelOrder[L4]);

                If(isBearBOS) bos[target] = -1;
                level[target] = IIF(bos[target] != 0, levelOrder[L2], 0);

                Bool isBullCHoCH =
                    (highLowOrder[L1] == -1 And highLowOrder[L2] ==  1 And
                     highLowOrder[L3] == -1 And highLowOrder[L4] ==  1 And
                     levelOrder[L4] > levelOrder[L2] And
                     levelOrder[L2] > levelOrder[L1] And
                     levelOrder[L1] > levelOrder[L3]);

                choch[target] = IIF(isBullCHoCH, 1, 0);
                If(choch[target] != 0) level[target] = levelOrder[L2];

                Bool isBearCHoCH =
                    (highLowOrder[L1] ==  1 And highLowOrder[L2] == -1 And
                     highLowOrder[L3] ==  1 And highLowOrder[L4] == -1 And
                     levelOrder[L4] < levelOrder[L2] And
                     levelOrder[L2] < levelOrder[L1] And
                     levelOrder[L1] < levelOrder[L3]);

                If(isBearCHoCH) choch[target] = -1;
                If(choch[target] != 0) level[target] = levelOrder[L2];
            }
            ArrayPushBack(lastPositions, i);
        }
        For i = 0 To size - 1
        {
            If(bos[i] == 0 And choch[i] == 0)
            {
                continue;
            }
            Bool isBull = (bos[i] == 1 || choch[i] == 1);
            Bool isBear = (bos[i] == -1 || choch[i] == -1);
            
            For j = i + 2 To size - 1
            {
                Bool broke = False;

                If(isBull)
                {
                    Numeric px = IIF(closeBreak, closeArr[j], highArr[j]);
                    If(px > level[i])
                    {
                        broke = True;
                    }
                }
                else If(isBear)
                {
                    Numeric px = IIF(closeBreak, closeArr[j], lowArr[j]);
                    If(px < level[i])
                    {
                        broke = True;
                    }
                }
                If(broke)
                {
                    broken[i] = j;
                    For k = 0 To i - 1
                    {
                        If((bos[k] != 0 || choch[k] != 0) And broken[k] >= j)
                        {
                            bos[k]   = 0;
                            choch[k] = 0;
                            level[k] = 0;
                            broken[k]   = -1;
                        }
                    }
                    Break;
                }
            }
        }
        For i = 0 To size - 1
        {
            If((bos[i] != 0 || choch[i] != 0) && broken[i] == -1)
            {
                bos[i]   = 0;
                choch[i] = 0;
                level[i] = 0;
            }
        }
        Return True;
    }


    Bool CalculateOb(Array<Numeric> openArr, Array<Numeric> highArr, Array<Numeric> lowArr, Array<Numeric> closeArr, Array<Numeric> volumeArr, Integer size, Array<Integer> highLows, Array<Numeric> levels, Bool closeMitigation, ArrayRef<Integer> ob, ArrayRef<Numeric> top, ArrayRef<Numeric> bottom, ArrayRef<Numeric> obvolume, ArrayRef<Integer> mitigatedIndex, ArrayRef<Numeric> percentage)
    {
        SetArraySize(ob, size, 0);
        SetArraySize(top, size, 0);
        SetArraySize(bottom, size, 0);
        SetArraySize(obvolume, size, 0);
        SetArraySize(mitigatedIndex, size, -1);
        SetArraySize(percentage, size, 0);
        Integer i = -1;
        Integer j = -1;
        Integer close_index = -1;
        
        // 预计算摆动高点/低点索引
        Array<Integer> swingHighIdx;
        Array<Integer> swingLowIdx;
        For i = 0 To size - 1
        {
            If(highLows[i] == 1)
            {
                ArrayPushBack(swingHighIdx, i);
            }
            Else If(highLows[i] == -1)
            {
                ArrayPushBack(swingLowIdx, i);
            }
        }
        // 工作数组
        Array<Bool>    crossed;
        Array<Bool>    breaker;
        Array<Numeric> lowVolume;
        Array<Numeric> highVolume;
        SetArraySize(crossed,    size,  False);
        SetArraySize(breaker,    size,  False);
        SetArraySize(lowVolume,  size,  0);
        SetArraySize(highVolume, size,  0); 

        // 看涨订单块
        Array<Integer> activeBull;
        For close_index = 0 To size - 1
        {
            // 更新已有的看涨 OB
            i = 0;
            j = GetArraySize(activeBull);
            While(i < j)
            {
                Integer idx = activeBull[i];
                If(breaker[idx])
                {
                    // 已被缓解，但价格又向上突破 OB 顶部 => 重置并移除  IIF(a, b, c);   
                    If(highArr[close_index] > top[idx])
                    {
                        ob[idx]             = 0;
                        top[idx]            = 0;
                        bottom[idx]         = 0;
                        obvolume[idx]       = 0;
                        lowVolume[idx]      = 0;
                        highVolume[idx]     = 0;
                        mitigatedIndex[idx] = -1;
                        percentage[idx]     = 0;
                        ArrayErase(activeBull, i, 1);
                        i = i - 1;
                        j = GetArraySize(activeBull);
                    }
                }
                Else
                {
                    Bool mitigate;
                    If(!closeMitigation)
                    {
                        mitigate = (lowArr[close_index] < bottom[idx]);
                    }
                    Else
                    {
                        mitigate = (Min(openArr[close_index], closeArr[close_index]) < bottom[idx]);
                    }
                    If(mitigate)
                    {
                        breaker[idx]         = True;
                        mitigatedIndex[idx]  = close_index - 1;
                    }
                }
                i = i + 1;
            }
            // 找到 close_index 之前最近的摆动高点
            Integer last_top_index = -1;
            Integer lo = 0;
            Integer hi = GetArraySize(swingHighIdx) - 1;
            If(hi >= 0 && close_index > swingHighIdx[0])
            {
                If(hi == 0)
                {
                    last_top_index = swingHighIdx[0];
                }
                Else If (hi == 1)
                {
                    If (close_index > swingHighIdx[1])
                    {
                        last_top_index = swingHighIdx[1];
                    }
                    Else
                    {
                        last_top_index = swingHighIdx[0];
                    }
                }
                Else
                {
                    While(lo < hi - 1)
                    {
                        Integer mider = IntPart((lo + hi) / 2);
                        If(swingHighIdx[mider] < close_index)
                        {
                            lo = mider;
                        }
                        Else
                        {
                            hi = mider;
                        }
                    }
                    last_top_index = swingHighIdx[lo];
                }
            }
            // 若收盘价突破该摆动高点且未 cross 过，创建看涨
            If(last_top_index >= 0)
            {
                If(closeArr[close_index] > highArr[last_top_index] && !crossed[last_top_index])
                {
                    crossed[last_top_index] = True;
                    Integer default_index   = close_index - 1;
                    Numeric obBtm           = lowArr[default_index];
                    Numeric obTop           = highArr[default_index];
                    Integer    obIndex      = default_index;

                    // 在 (last_top_index, close_index) 之间寻找最低的低点
                    If(close_index - last_top_index > 1)
                    {
                        Integer start = last_top_index + 1;
                        Integer tail  = close_index;
                        If(tail > start)
                        {
                            Numeric  minVal = lowArr[start];
                            Integer candIdx = start;
                            For i = start + 1 To tail - 1
                            {
                                // 相等时取最后一个
                                If(lowArr[i] <= minVal)
                                {
                                    minVal  = lowArr[i];
                                    candIdx = i;
                                }
                            }
                            obBtm   = lowArr[candIdx];
                            obTop   = highArr[candIdx];
                            obIndex = candIdx;
                        }
                    }
                    ob[obIndex]     = 1;
                    top[obIndex]    = obTop;
                    bottom[obIndex] = obBtm;

                    Numeric vol_cur   = volumeArr[close_index];
                    Numeric vol_prev1 = IIF((close_index >= 1), volumeArr[close_index - 1], 0.0);
                    Numeric vol_prev2 = IIF((close_index >= 2), volumeArr[close_index - 2], 0.0);
                    obvolume[obIndex] = vol_cur + vol_prev1 + vol_prev2;

                    lowVolume[obIndex]   = vol_prev2;
                    highVolume[obIndex]  = vol_cur + vol_prev1;
                    Numeric max_vol = Max(highVolume[obIndex], lowVolume[obIndex]);
                    percentage[obIndex] = IIF((max_vol != 0.0), (Min(highVolume[obIndex], lowVolume[obIndex]) / max_vol * 100.0), 100.0);

                    ArrayPushBack(activeBull, obIndex);
                }
            }
        }

        // 看跌订单块
        Array<Integer> activeBear;
        For close_index = 0 To size - 1
        {
            // 更新已有的看跌
            i = 0;
            j = GetArraySize(activeBear);
            While(i < j)
            {
                Integer idx = activeBear[i];
                If(breaker[idx])
                {
                    // 已被失效，但价格又向下突破 OB 底部 => 重置并移除
                    If(lowArr[close_index] < bottom[idx])
                    {
                        ob[idx]             = 0;
                        top[idx]            = 0;
                        bottom[idx]         = 0;
                        obvolume[idx]       = 0;
                        lowVolume[idx]      = 0;
                        highVolume[idx]     = 0;
                        mitigatedIndex[idx] = -1;
                        percentage[idx]     = 0;
                        ArrayErase(activeBear, i, 1);
                        i = i - 1;
                        j = GetArraySize(activeBull);
                    }
                }
                Else
                {
                    Bool mitigate;
                    If(!closeMitigation)
                    {
                        mitigate = (highArr[close_index] > top[idx]);
                    }  
                    Else
                    {
                        mitigate = (Max(openArr[close_index], closeArr[close_index]) > top[idx]);
                    }
                    If(mitigate)
                    {
                        breaker[idx]         = True;
                        mitigatedIndex[idx]  = close_index;
                    }
                }
                i = i + 1;
            }
            Integer last_btm_index = -1;
            Integer lo = 0;
            Integer hi = GetArraySize(swingLowIdx) - 1;
            If(hi >= 0 && close_index > swingLowIdx[0])
            {
                If(hi == 0)
                {
                    last_btm_index = swingLowIdx[0];
                }
                Else If (hi == 1)
                {
                    If (close_index > swingLowIdx[1])
                    {
                        last_btm_index = swingLowIdx[1];
                    }
                    Else
                    {
                        last_btm_index = swingLowIdx[0];
                    }
                }
                Else
                {
                    While(lo < hi - 1)
                    {
                        Integer mider = IntPart((lo + hi) / 2);
                        If(swingLowIdx[mider] < close_index)
                        {
                            lo = mider;
                        }
                        Else
                        {
                            hi = mider;
                        }
                    }
                    last_btm_index = swingLowIdx[lo];
                }
            }
            // 若收盘价跌破该摆动低点且未 cross 过，创建看跌 OB
            If(last_btm_index >= 0)
            {
                If(closeArr[close_index] < lowArr[last_btm_index] && !crossed[last_btm_index])
                {
                    crossed[last_btm_index]  = True;
                    Integer    default_index = close_index - 1;
                    Numeric obTop            = highArr[default_index];
                    Numeric obBtm            = lowArr[default_index];
                    Integer    obIndex       = default_index;
                    If(close_index - last_btm_index > 1)
                    {
                        Integer start = last_btm_index + 1;
                        Integer tail   = close_index;
                        If(tail > start)
                        {
                            Numeric maxVal  = highArr[start];
                            Integer    candIdx = start;
                            For i = start + 1 To tail - 1
                            {
                                If(highArr[i] >= maxVal)
                                {
                                    maxVal  = highArr[i];
                                    candIdx = i;
                                }
                            }
                            obTop   = highArr[candIdx];
                            obBtm   = lowArr[candIdx];
                            obIndex = candIdx;
                        }
                    }
                    ob[obIndex]     = -1;
                    top[obIndex]    = obTop;
                    bottom[obIndex] = obBtm;

                    Numeric vol_cur   = volumeArr[close_index];
                    Numeric vol_prev1 = IIF((close_index >= 1), volumeArr[close_index - 1], 0.0);
                    Numeric vol_prev2 = IIF((close_index >= 2), volumeArr[close_index - 2], 0.0);
                    obvolume[obIndex] = vol_cur + vol_prev1 + vol_prev2;

                    lowVolume[obIndex]   = vol_cur + vol_prev1;
                    highVolume[obIndex]  = vol_prev2;
                    Numeric max_vol = Max(highVolume[obIndex], lowVolume[obIndex]);
                    percentage[obIndex] = IIF((max_vol != 0.0), (Min(highVolume[obIndex], lowVolume[obIndex]) / max_vol * 100.0), 100.0);

                    ArrayPushBack(activeBear, obIndex);
                }
            }
        }
        Return True;
    }


    Bool CalculateLiquidity(Array<Numeric> openArr, Array<Numeric> highArr, Array<Numeric> lowArr, Array<Numeric> closeArr, Integer size, Array<Integer> highLows, Array<Numeric> levels, Numeric rangePercent, ArrayRef<Integer> liquidity, ArrayRef<Numeric> level, ArrayRef<Integer> tail, ArrayRef<Integer> swept)
    {
        SetArraySize(liquidity, size, 0);
        SetArraySize(level, size, 0);
        SetArraySize(tail, size, -1);
        SetArraySize(swept, size, -1);   

        Integer i = -1;
        Integer j = -1;
        Numeric maxHigh = 0;
        Numeric maxLow = 0;
        Numeric pip_range = 0;
        maxHigh = highArr[0];
        maxLow = lowArr[0];
        For i = 1 To size - 1
        {
            If (highArr[i] > maxHigh)
            {
                maxHigh = highArr[i];
            } 
            If (lowArr[i] < maxLow)
            {
                maxLow = lowArr[i];
            }   
        }
        pip_range = (maxHigh - maxLow) * rangePercent;
        
        Array<Integer> HL;
        Array<Numeric> LevelVals;
        SetArraySize(HL, size, 0);
        SetArraySize(LevelVals, size, 0);
        For i = 0 To size - 1
        {
            HL[i] = HighLows[i];
            LevelVals[i] = Levels[i];
        }
        
        Integer sw = -1;
        Integer group_cnt = -1;
        Integer group_end = -1;
        Numeric high_level = 0;
        Numeric low_level = 0;
        Numeric rng_low = 0;
        Numeric rng_high = 0;
        Numeric group_sum = 0;
        For i = 0 To size - 1
        {
            If (HL[i] != 1)
            {
                Continue;
            }
            high_level = LevelVals[i];
            rng_low = high_level - pip_range;
            rng_high = high_level + pip_range;
            group_sum = high_level;
            group_cnt = 1;
            group_end = i;
            sw = 0;
            For j = i + 1 To size - 1
            {
                If (highArr[j] >= rng_high)
                {
                    sw = j;
                    Break;
                }
            }
            For j = i + 1 To size - 1
            {
                If (HL[j] != 1)
                {
                    Continue;
                }
                If (sw > 0 And j >= sw)
                {
                    Break;
                }
                If (LevelVals[j] >= rng_low And LevelVals[j] <= rng_high)
                {
                    group_sum = group_sum + LevelVals[j];
                    group_cnt = group_cnt + 1;
                    group_end = j;
                    HL[j] = 0;
                }
            }  
            If (group_cnt > 1)
            {
                liquidity[i] = 1;
                level[i] = group_sum / group_cnt;
                tail[i] = group_end;
                swept[i] = sw;          
            
            }
        }
        For i = 0 To size - 1
        {
            If (HL[i] != -1)
            {
                Continue;
            }
            low_level = LevelVals[i];
            rng_low = low_level - pip_range;
            rng_high = low_level + pip_range;
            group_sum = low_level;
            group_cnt = 1;
            group_end = i;
            sw = 0;
            For j = i + 1 To size - 1
            {
                If (lowArr[j] <= rng_low)
                {
                    sw = j;
                    Break;
                }
            }
            For j = i + 1 To size - 1
            {
                If (HL[j] != -1)
                {
                    Continue;
                }
                If (sw > 0 And j >= sw)
                {
                    Break;
                }
                If (LevelVals[j] >= rng_low And LevelVals[j] <= rng_high)
                {
                    group_sum = group_sum + LevelVals[j];
                    group_cnt = group_cnt + 1;
                    group_end = j;
                    HL[j] = 0;
                }
            }
            If (group_cnt > 1)
            {
                liquidity[i] = -1;
                level[i] = group_sum / group_cnt;
                tail[i] = group_end;
                swept[i] = sw;
            } 
        }
        Return True;
    }


    Bool CalculatePreviousHighLow(Array<Numeric> highArr, Array<Numeric> lowArr, Array<Numeric> timeArr, Array<Numeric> longTimeArr, Integer size, Integer longSize, ArrayRef<Numeric> previousHigh, ArrayRef<Numeric> previousLow, ArrayRef<Integer> brokenHigh, ArrayRef<Integer> brokenLow)
    {
        SetArraySize(previousHigh, size, 0);
        SetArraySize(previousLow,  size, 0);
        SetArraySize(brokenHigh,   size, 0);
        SetArraySize(brokenLow,    size, 0);
        Integer i = -1;
        Integer shift = -1;
        For shift = size - 1 DownTo 0
        {
            Numeric curTimeVal = timeArr[shift];
            If (curTimeVal <= 0)
            {
                Continue;
            }
            Numeric longShift = -1;
            For i = longSize - 1 DownTo 0
            {
                If (longTimeArr[i] <= curTimeVal)
                {
                    longShift = i;
                    Break;
                }
            }
            If (longShift - 1 < 0)
            {
                Continue;
            }
            Numeric prevHigh = LongHighs[longShift - 1];
            Numeric prevLow = LongLows[longShift - 1];
            If (prevHigh == 0.0 Or prevLow == 0.0)
            {
                Continue;
            }

            Numeric groupStartTime = longTimeArr[longShift];
            Numeric groupStartLowShift = -1;
            For i = size - 1 DownTo 0
            {
                If (timeArr[i] <= groupStartTime)
                {
                    groupStartLowShift = i;
                    Break;
                }
            }
            If (groupStartLowShift < 0)
            {
                Continue;
            }
            If (groupStartLowShift > shift)
            {
                groupStartLowShift = shift;
            }
            Numeric cumHigh = 0;
            Numeric cumLow = 999999999;
            Numeric m = 0;
            Numeric n = 0;
            For i = groupStartLowShift To shift
            {
                m = highArr[i];
                n = lowArr[i];
                If (m == 0 And n == 0)
                {
                    Continue;
                }
                If (m > cumHigh)
                {
                    cumHigh = m;
                }
                If (n < cumLow)
                {
                    cumLow = n;
                }
            }
            previousHigh[shift] = prevHigh;
            previousLow[shift] = prevLow;
            If (cumHigh > prevHigh)
            {
                brokenHigh[shift] = 1;
            }
            If (cumLow < prevLow)
            {
                brokenLow[shift] = 1;
            }
        }
        Return True;
    }


    Bool CalculateTimeFrameBosChoch(Array<Numeric> longHighArr, Array<Numeric> longLowArr, Array<Numeric> longCloseArr, Array<Numeric> timeArr, Array<Numeric> longTimeArr, Integer size, Integer longSize, bool closeBreak, ArrayRef<Integer> bos, ArrayRef<Integer> choch, ArrayRef<Numeric> level, ArrayRef<Integer> broken)
    {
        Numeric startTime = timeArr[0];
        Numeric endTime = timeArr[size - 1];
        Integer i = -1;
        Integer j = -1;
        Integer shift = -1;
        Integer startShift = -1;
        Integer endShift = -1;
        For i = longSize - 1 DownTo 0
        {
            Numeric curTimeVal = longTimeArr[i];
            If (curTimeVal <= 0)
            {
                Continue;
            }
            If (curTimeVal <= startTime)
            {
                startShift = i;
                Break;
            }
        }
        For i = longSize - 1 DownTo 0
        {
            Numeric curTimeVal = longTimeArr[i];
            If (curTimeVal <= 0)
            {
                Continue;
            }
            If (curTimeVal <= endTime)
            {
                endShift = i;
                Break;
            }
        }
        Integer count = endShift - startShift + 1;
        If (startShift < 0 Or endShift < 0 Or count <= 0)
        {
            Return False;
        }
        Array<Numeric> highsAggregation;
        Array<Numeric> lowsAggregation;
        Array<Numeric> closesAggregation;
        Array<Numeric> timesAggregation;
        SetArraySize(highsAggregation,  count, 0);
        SetArraySize(lowsAggregation,   count, 0);
        SetArraySize(closesAggregation, count, 0);
        SetArraySize(timesAggregation, count, 0);
        For i = 0 To longSize - 1
        {
            If (i < startShift Or i > endShift)
            {
                Continue;
            }
            j = j + 1;
            highsAggregation[j]  = longHighArr[i];
            lowsAggregation[j]   = longLowArr[i];
            closesAggregation[j] = longCloseArr[i];
            timesAggregation[j]  = longTimeArr[i];
        }
        Integer aggregationSize = j;
        SetArraySize(bos, size, 0);
        SetArraySize(choch, size, 0);
        SetArraySize(level, size, 0);
        SetArraySize(broken, size, -1);

        Array<Integer> swingHighLows;
        Array<Numeric> swingLevels;
        CalculateSwingHighsLows(highsAggregation, lowsAggregation, aggregationSize, SwingLengthAggregation, swingHighLows, swingLevels);
        Array<Integer> bosAggregation;
        Array<Integer> chochAggregation;
        Array<Numeric> levelAggregation;
        Array<Integer> brokenAggregation;
        CalculateBosChoch(highsAggregation, lowsAggregation, closesAggregation, aggregationSize, swingHighLows, swingLevels, true, bosAggregation, chochAggregation, levelAggregation, brokenAggregation);
        For shift = size - 1 DownTo 0
        {
            Numeric curTimeVal = timeArr[shift];
            If (curTimeVal <= 0)
            {
                Continue;
            }
            Numeric aggregationShift = -1;
            For i = aggregationSize - 1 DownTo 0
            {
                If (timesAggregation[i] <= 0)
                {
                    Continue;
                }
                If (timesAggregation[i] <= curTimeVal)
                {
                    aggregationShift = i;
                    Break;
                }
            }
            If (aggregationShift < 0)
            {
                Continue;
            }
            bos[shift]    = bosAggregation[aggregationShift];
            choch[shift]  = chochAggregation[aggregationShift];
            level[shift]  = levelAggregation[aggregationShift];
            j             = brokenAggregation[aggregationShift];
            If (j < 0)
            {
                broken[shift] = - 1;
            }
            Else If (j >= aggregationSize -1)
            {
                broken[shift] = size - 1;
            }
            Else
            {
                For i = size - 1 DownTo 0
                {
                    Numeric curTimeVal = timeArr[i];
                    If (curTimeVal <= 0)
                    {
                        Continue;
                    }
                    If (curTimeVal < timesAggregation[j + 1])
                    {
                        broken[shift] = i;
                        Break;
                    }
                }
            }
        }
        Return True;
    }


    Bool GenerateSignals(Integer size, Integer longSize, Numeric ask, Numeric bid, IntegerRef isLong, IntegerRef isShort, NumericRef sl, NumericRef tp1, NumericRef tp2, NumericRef tp3)
    {
        Array<Integer> bosAggregation;
        Array<Integer> chochAggregation;
        Array<Numeric> levelAggregation;
        Array<Integer> brokenAggregation;
        CalculateTimeFrameBosChoch(LongHighs, LongLows, LongCloses, Times, LongTimes, size, longSize, true, bosAggregation, chochAggregation, levelAggregation, brokenAggregation);

        Array<Numeric> pvPreviousHigh;
        Array<Numeric> pvPreviousLow;
        Array<Integer> pvBrokenHigh;
        Array<Integer> pvBrokenLow;
        CalculatePreviousHighLow(Highs, Lows, Times, LongTimes, size, longSize, pvPreviousHigh, pvPreviousLow, pvBrokenHigh, pvBrokenLow);

        Array<Integer> swingHighLows;
        Array<Numeric> swingLevels;
        CalculateSwingHighsLows(Highs, Lows, size, SwingLength, swingHighLows, swingLevels);

        Array<Integer> bcBos;
        Array<Integer> bcChoch;
        Array<Numeric> bcLevel;
        Array<Integer> bcBroken;
        CalculateBosChoch(Highs, Lows, Closes, size, swingHighLows, swingLevels, true, bcBos, bcChoch, bcLevel, bcBroken);

        Array<Integer> obOb;
        Array<Numeric> obTop;
        Array<Numeric> obBottom;
        Array<Numeric> obObvolume;
        Array<Integer> obMitigatedIndex;
        Array<Numeric> obPercentage;
        CalculateOb(Opens, Highs, Lows, Closes, Volumes, size, swingHighLows, swingLevels, false, obOb, obTop, obBottom, obObvolume, obMitigatedIndex, obPercentage);

        Array<Integer> fvgFvg;
        Array<Numeric> fvgTop;
        Array<Numeric> fvgBottom;
        Array<Integer> fvgMitigatedIndex;
        CalculateFVG(Opens, Highs, Lows, Closes, size, true, fvgFvg, fvgTop, fvgBottom, fvgMitigatedIndex);

        Array<Integer> liqLiquidity;
        Array<Numeric> liqLevel;
        Array<Integer>    liqTail;
        Array<Integer>    liqSwept;
        CalculateLiquidity(Opens, Highs, Lows, Closes, size, swingHighLows, swingLevels, 0.01, liqLiquidity, liqLevel, liqTail, liqSwept);

        Array<Numeric> longScore;
        Array<Numeric> shortScore;
        SetArraySize(longScore, size, 0);
        SetArraySize(shortScore, size, 0);

        Integer i = -1;
        Integer j = -1;
        For i = 0 To size - 1
        {
            Numeric pvH = pvPreviousHigh[i];
            Numeric pvL = pvPreviousLow[i];
            Integer bH  = pvBrokenHigh[i];
            Integer bL  = pvBrokenLow[i];
            Bool bull   = (bH == 1) && pvH > 0 && (Closes[i] > pvH);
            Bool bear   = (bL == 1) && pvL > 0 && (Closes[i] < pvL);
            If(bull) longScore[i]  = longScore[i] + PreviousHighLowStrength;
            If(bear) shortScore[i] = shortScore[i] + PreviousHighLowStrength;
        }

        // 聚合成高周期，投射到低周期后，BOS/CHOCH 评分 ， 按 BrokenIndex 位置计分
        For i = 0 To size - 1
        {
            Numeric bos  = bosAggregation[i];
            Integer j    = brokenAggregation[i];
            If(bos == 0 || j < 0)
            {
                continue;
            }
            If(bos == 1)
            {
                longScore[j] = longScore[j] + BosStrengthAggregation;
            }
            Else If(bos == -1)
            {
                shortScore[j] = shortScore[j] + BosStrengthAggregation;
            }
        }

        // BOS CHOCH 评分
        For i = 0 To size - 1
        {
            Numeric bos   = bcBos[i];
            Numeric choch = bcChoch[i];
            Integer j     = bcBroken[i];
            If(j < 0)
            {
                continue;
            }
            If(bos != 0)
            {
                If(bos == 1)
                {
                    longScore[j] = longScore[j] + BosStrength;
                }
                Else If(bos == -1)
                {
                    shortScore[j] = shortScore[j] + BosStrength;
                }
            }
            If(choch != 0)
            {
                If(choch == 1)
                {
                    longScore[j] = longScore[j] + ChochStrength;
                }
                Else If(choch == -1)
                {
                    shortScore[j] = shortScore[j] + ChochStrength;
                }
            }
        }

        // 回踩评分
        For i = 0 To size - 1
        {
            Integer ob      = obOb[i];
            Numeric top     = obTop[i];
            Numeric bottom  = obBottom[i];
            Integer index   = obMitigatedIndex[i];
            If(ob == 0)
            {
                continue;
            }
            Integer tail = size - 1;
            If(index > -1)
            {
                tail = index;
            }
            For j = i + 1 To tail
            {
                If(ob == 1 && Lows[j] <= top && Closes[j] > top)
                {
                    longScore[j] = longScore[j] + obStrength;
                    Break;
                }
                If(ob == -1 && Highs[j] >= bottom && Closes[j] < bottom)
                {
                    shortScore[j] = shortScore[j] + obStrength;
                    Break;
                }
            }
        }

        // FVG 回踩评分
        For i = 0 To size - 1
        {
            Integer fvg     = fvgFvg[i];
            Numeric top     = fvgTop[i];
            Numeric bottom  = fvgBottom[i];
            Integer index   = fvgMitigatedIndex[i];
            If(fvg == 0)
            {
                continue;
            }
            Integer tail = size - 1;
            If(index > -1)
            {
                tail = index;
            }
            For j = i + 2 To tail
            {
                If(fvg == 1 && Lows[j] <= top && Closes[j] > top)
                {
                    longScore[j] = longScore[j] + fvgStrength;
                    Break;
                }
                If(fvg == -1 && Highs[j] >= bottom && Closes[j] < bottom)
                {
                    shortScore[j] = shortScore[j] + fvgStrength;
                    Break;
                }
            }
        }

        // 流动性扫掠评分
        Integer maxGap = 50;
        For i = 0 To size - 1
        {
            Integer liquidity  = liqLiquidity[i];
            Numeric level      = liqLevel[i];
            Integer tail       = liqTail[i];
            Integer j          = liqSwept[i];
            If (liquidity == 0 || j <= 0)
            {
                continue;
            }
            If(tail > -1 && (j - tail) > maxGap)
            {
                continue;
            }
            If(liquidity == -1 && Closes[j] > level)
            {
                longScore[j] = longScore[j] + liquidityStrength;
            }
            Else If(liquidity == 1 && Closes[j] < level)
            {
                shortScore[j] = longScore[j] + liquidityStrength;
            }
        }

        Array<Integer> signals;
        Array<Integer> strongs;
        SetArraySize(signals,   size, 0);
        SetArraySize(strongs,   size, 0);
        For i = 0 To size - 1
        {
            Numeric net = longScore[i] - shortScore[i];
            If(net >=  entryThreshold)
            {
                signals[i] = 1;
            }
            Else If(net <= -entryThreshold)
            {
                signals[i] = -1;
            }
            Else
            {
                signals[i] = 0;
            }
            If(net >=  strongThreshold)
            {
                strongs[i] = 1;
            }
            Else If(net <= -strongThreshold)
            {
                strongs[i] = -1;
            }
            Else
            {
                strongs[i] = 0;
            }
        }


        Integer lastIndex = size - 1;
        Numeric sltpAtr = 0;
        Array<Numeric> supports;
        Array<Numeric> longTp1Candidates;
        Array<Numeric> longTp2Candidates;
        Array<Numeric> resistances;
        Array<Numeric> shortTp1Candidates;
        Array<Numeric> shortTp2Candidates;
        Numeric entry = 0;
        Numeric atr = ATRs[1];
        Numeric buffer = Max(0.5 * atr, 2 * SltpSpread);
        If (signals[lastIndex] == 1)
        {
            isLong = 1;
            entry = ask;
            For i = lastIndex DownTo 0
            {
                If(swingHighLows[i] == -1 && swingLevels[i] > 0)
                {
                    ArrayPushBack(supports, swingLevels[i]);
                    Break;
                }
            }
            // 最近未失效看涨 OB
            For i = lastIndex DownTo 0
            {
                If(obOb[i] == 1)
                {
                    Numeric mit = obMitigatedIndex[i];
                    If(mit < 0 || mit >= lastIndex)
                    {
                        ArrayPushBack(supports, obBottom[i]);
                        Break;
                    }
                }
            }
            // 最近未失效看涨 FVG
            For i = lastIndex DownTo 0
            {
                If(fvgFvg[i] == 1)
                {
                    Numeric mit = fvgMitigatedIndex[i];
                    If(mit < 0 || mit > lastIndex)
                    {
                        ArrayPushBack(supports, fvgBottom[i]);
                        Break;
                    }
                }
            }
            // 上方流动性 或 前高
            For i = lastIndex DownTo 0
            {
                If(liqLiquidity[i] == 1)
                {
                    ArrayPushBack(longTp1Candidates, liqLevel[i]);
                    Break;
                }
            }
            If(pvPreviousHigh[lastIndex] > 0)
            {
                ArrayPushBack(longTp1Candidates, pvPreviousHigh[lastIndex]);
            }
            // 上方看跌 OB/FVG
            For i = lastIndex DownTo 0
            {
                If(obOb[i] == -1)
                {
                    ArrayPushBack(longTp2Candidates, obTop[i]);
                    Break;            
                }
            }
            For i = lastIndex DownTo 0
            {
                If(fvgFvg[i] == -1)
                {
                    ArrayPushBack(longTp2Candidates, fvgTop[i]);
                    Break;

                }
            }
            Numeric _max = 0;
            Numeric _min = 0;
            Integer count = GetArraySize(supports);
            For i = 0 To count - 1
            {
                Numeric item = supports[i];
                If(item < entry)
                {
                    _max = Max(_max, item);
                }
                
            }
            Numeric _sl = IIF(_max > 0, _max - buffer, entry - 1.5 * atr);

            count = GetArraySize(longTp1Candidates);
            For i = 0 To count - 1
            {
                Numeric item = longTp1Candidates[i];
                If(item > entry)
                {
                    _min = Min(_min, item);
                }
            }
            tp1 = IIF(_min > 0, _min, entry + 2 * (entry - _sl));

            _min = 0;
            count = GetArraySize(longTp2Candidates);
            For i = 0 To count - 1
            {
                Numeric item = longTp2Candidates[i];
                If(item > entry)
                {
                    _min = Min(_min, item);
                }
            }
            tp2 =  IIF(_min > 0, _min, entry + 3 * (entry - _sl));
            tp3 = entry + 3 * (entry - _sl);
            sl =_sl;
        }
        Else If (signals[lastIndex] == -1)
        {
            isShort = 1;
            entry = bid;
            For i = lastIndex DownTo 0
            {
                If(swingHighLows[i] == 1 && swingLevels[i] > 0)
                {
                    ArrayPushBack(resistances, swingLevels[i]);
                    Break;
                }
            }
            For i = lastIndex DownTo 0
            {
                If(obOb[i] == -1)
                {
                    Numeric mit = obMitigatedIndex[i];
                    If(mit < 0 || mit >= lastIndex)
                    {
                        ArrayPushBack(resistances, obTop[i]);
                        Break;
                    }
                }
            }
            For i = lastIndex DownTo 0
            {
                If(fvgFvg[i] == -1)
                {
                    Numeric mit = fvgMitigatedIndex[i];
                    If(mit < 0 || mit > lastIndex)
                    {
                        ArrayPushBack(resistances, fvgTop[i]);
                        Break;
                    }
                }
            }
            For i = lastIndex DownTo 0
            {
                If(liqLiquidity[i] == -1)
                {
                    ArrayPushBack(shortTp1Candidates, liqLevel[i]);
                    Break;
                }
            }
            If(pvPreviousLow[lastIndex] > 0)
            {
                ArrayPushBack(shortTp1Candidates, pvPreviousLow[lastIndex]);
            }
            For i = lastIndex DownTo 0
            {
                If(obOb[i] == 1)
                {
                    ArrayPushBack(shortTp2Candidates, obBottom[i]);
                    Break;
                }
            }
            For i = lastIndex DownTo 0
            {
                If(fvgFvg[i] == 1)
                {
                    ArrayPushBack(shortTp2Candidates, fvgBottom[i]);
                    Break;

                }
            }
            Numeric _max = 0;
            Numeric _min = 0;
            Integer count = GetArraySize(resistances);
            For i = 0 To count - 1
            {
                Numeric item = resistances[i];
                If(item > entry)
                {
                    _min = Min(_min, item);
                }
            }
            Numeric _sl = IIF(_min > 0, _min + buffer, entry + 1.5 * atr);

            count = GetArraySize(shortTp1Candidates);
            For i = 0 To count - 1
            {
                Numeric item = shortTp1Candidates[i];
                If(item < entry)
                {
                    _max = Max(_max, item);
                }
            }
            tp1 = IIF(_max > 0, _max, entry - 2 * (_sl - entry));

            _max = 0;
            count = GetArraySize(shortTp2Candidates);
            For i = 0 To count - 1
            {
                Numeric item = shortTp2Candidates[i];
                If(item < entry)
                {
                    _max = Max(_max, item);
                }
            }
            tp2 = IIF(_max > 0, _max, entry - 3 * (_sl - entry));
            tp3 = entry - 3 * (_sl - entry);
            sl =_sl;
        }


        // Print(TextArray(signals));
        // Print(TextArray(strongs));
        



        // Array<Numeric> outLongScore;
        // Array<Numeric> outShortScore;
        // For i = 0 To size - 1
        // {
        //     If (longScore[i] > 0){
        //         ArrayPushBack(outLongScore, longScore[i]);
        //     }
        //     If (shortScore[i] > 0){
        //         ArrayPushBack(outShortScore, shortScore[i]);
        //     }
        // }
        // If (GetArraySize(outLongScore) >0)
        // {
        //     Print("1: " + TextArray(outLongScore));
        //     Print(TextArray(longScore));
        // }
        // If (GetArraySize(outShortScore) >0)
        // {
        //     Print("2: " + TextArray(outShortScore));
        //     Print(TextArray(shortScore));
        // }


        


        Return True;
    }



    Bool validateStops(Bool isBuy, Numeric ask, Numeric bid, Numeric sl1, Numeric tp1, Numeric tp2, Numeric tp3, NumericRef sl, NumericRef tp)
    {
        sl = 0;
        tp = 0;
        If(isBuy)
        {
            If(InpStopLoss > 0)
            {
                sl = ask * (1- InpStopLoss);
                If(sl < sl1 && sl1 < ask)
                {
                    sl = sl1;
                }
            }
            If(InpTakeProfit > 0)
            {
                tp = ask * (1 + InpTakeProfit);
                Numeric tp0 = (tp1 + tp2) / 2;
                If(tp > tp0 && tp0 > ask)
                {
                    tp = tp0;
                }
            }
        }
        Else
        {
            If(InpStopLoss > 0)
            {
                sl = bid * (1 + InpStopLoss);
                If(sl > sl1 && sl1 > bid)
                {
                    sl = sl1;
                }
            }
            If(InpTakeProfit > 0)
            {
                tp = bid * (1 - InpTakeProfit);
                Numeric tp0 = (tp1 + tp2) / 2;
                If(tp < tp0 && tp0 < bid)
                {
                    tp = tp0;
                }
            }
        }
        If(sl <= 0 Or tp <= 0)
        {
            Return False;
        }
        Return True;
    }






Events
    
    OnInit()
    {
        Range[0:DataCount-1]
        {
            //=========数据源相关设置==============
            //AddDataFlag(Enum_Data_RolloverBackWard());    //设置后复权

            //AddDataFlag(Enum_Data_RolloverRealPrice());    //设置映射真实价格

            //AddDataFlag(Enum_Data_AutoSwapPosition());    //设置自动换仓

            //AddDataFlag(Enum_Data_IgnoreSwapSignalCalc());    //设置忽略换仓信号计算

            //AddDataFlag(Enum_Data_OnlyDay());        //设置仅日盘
            
            //AddDataFlag(Enum_Data_OnlyNight());    //设置仅夜盘
            
            //AddDataFlag(Enum_Data_NotGenReport());    //设置数据源不参与生成报告标志
            
            //=========交易相关设置==============
            //SetMarginRate(0.1);    //设置保证金率为10%
            
            //CommissionRate tCommissionRate;
            //tCommissionRate.ratioType = Enum_Rate_ByFillAmount;
            //tCommissionRate.openRatio = 5; //设置开仓手续费为成交金额的5%%
            //tCommissionRate.closeRatio = 2; //设置平仓手续费为成交金额的2%%
            //tCommissionRate.closeTodayRatio = 0; //设置平今手续费为0
            //SetCommissionRate(tCommissionRate); //设置手续费率
            
            //SetSlippage(Enum_Rate_PointPerHand,2);    //设置滑点为2跳/手
            
            //SetOrderPriceOffset(2);    //设置委托价为叫买/卖价偏移2跳
            
            //SetOrderMap2MainSymbol();    //设置委托映射到主力
            
            //SetOrderMap2AppointedSymbol(symbols, multiples);     //设置委托映射到指定合约，symbols是映射合约数组，multiples是映射倍数数组
        }
        // timerId=createTimer(millsecs);
        // SetBeginBarMaxCount(10);
        //=========交易相关设置==============
        //SetInitCapital(1000000);    //设置初始资金为100万
        //AddTradeFlag(Enum_Trade_Ignore_Buy());    //设置忽略多开
        //AddTradeFlag(Enum_Trade_Ignore_Sell());    //设置忽略多平
        //AddTradeFlag(Enum_Trade_Ignore_SellShort());    //设置忽略空开
        //AddTradeFlag(Enum_Trade_Ignore_Buy2Cover());    //设置忽略空平
        //Bool ret = SubscribeTick("bc2611.INE");
        //Print("订阅当前合约Tick: " + IIFString(ret, "成功", "失败"));
        //plt.toolBar("ev_symbol","button",Text(SystemDateTime));
        //plt.toolBar("ev_symbol2", "合约代码", "rb2605", "input");
        
        SetBackBarMaxCount(UseBarCount * 2);
        SubscribeBar(Symbol, "1h", Data0.BeginDateTime);
        SetArraySize(Opens,   UseBarCount, 0);
        SetArraySize(Highs,   UseBarCount, 0);
        SetArraySize(Lows,    UseBarCount, 0);
        SetArraySize(Closes,  UseBarCount, 0);
        SetArraySize(Volumes, UseBarCount, 0);
        SetArraySize(Times,   UseBarCount, 0);
        Integer longSize = UseBarCount / 2;
        SetArraySize(LongOpens,   longSize, 0);
        SetArraySize(LongHighs,   longSize, 0);
        SetArraySize(LongLows,    longSize, 0);
        SetArraySize(LongCloses,  longSize, 0);
        SetArraySize(LongVolumes, longSize, 0);
        SetArraySize(LongTimes,   longSize, 0);

        Print("初始化完成，当前合约代码: " + Symbol);
    }


    
    OnReady()
    {
        //在所有的数据源准备完成后调用，应用在数据源的设置等操作
    }
    
    
    

    OnDic(StringRef dicName,StringRef dicSymbol,DicDataRef dicValue)
    {
        //基础数据更新事件函数
        
    }
    



    OnBarOpen(ArrayRef<Integer> indexs)
    {

        //在新bar的第一次执行之前调用一次，参数为新bar的图层数组
    }
    
    
    

    //Bar更新事件函数，参数indexs表示变化的数据源图层ID数组 avg = calcAvg(high,low);
    OnBar(ArrayRef<Integer> indexs)
    {
        BarCnt = CurrentBar + 1;
        If (BarCnt <= UseBarCount) 
        {
            Return;
        }
        Integer i = -1;
        Integer j = -1;
        Bar curBar;
        For i = 0 To UseBarCount - 1
        {
            j = UseBarCount - i;
            Opens[i]   = Open[j];
            Highs[i]   = High[j];
            Lows[i]    = Low[j];
            Closes[i]  = Close[j];
            Volumes[i] = Vol[j];
            If (GetBar(curBar, j))
            {
                Times[i] = curBar.datetime;
            }
        }
        Integer longSize = UseBarCount / 2;
        For i = 0 To longSize - 1
        {
            j = longSize - i;
            LongOpens[i]   = Data1.Open[j];
            LongHighs[i]   = Data1.High[j];
            LongLows[i]    = Data1.Low[j];
            LongCloses[i]  = Data1.Close[j];
            LongVolumes[i] = Data1.Vol[j];
            If (Data1.GetBar(curBar, j))
            {
                LongTimes[i] = curBar.datetime;
            }
        }
        ATRs = AvgTrueRange(14);
        Numeric ask = Open[0];
        Numeric bid = Open[0];
        Integer isLong = 0;
        Integer isShort = 0;
        Numeric sl1;
        Numeric tp1;
        Numeric tp2;
        Numeric tp3;
        GenerateSignals(UseBarCount, longSize, ask, bid, isLong, isShort, sl1, tp1, tp2, tp3);

        Numeric tradePrice = Open;
        If(MarketPosition <> 0)
        {
            If(MarketPosition == 1)
            {
                If(Low <= StopLossPrice)
                {
                    Sell(0, Min(Open, StopLossPrice));
                    Print("多头止损平仓 | 触发价: " + Text(StopLossPrice));
                    Return;
                }
                If(High >= TakeProfitPrice)
                {
                    Sell(0, Max(Open, TakeProfitPrice));
                    Print("多头止盈平仓 | 触发价: " + Text(TakeProfitPrice));
                    Return;
                }
            }
            If(MarketPosition == -1)
            {
                If(High >= StopLossPrice)
                {
                    BuyToCover(0, Max(Open, StopLossPrice));
                    Print("空头止损平仓 | 触发价: " + Text(StopLossPrice));
                    Return;
                }
                If(Low <= TakeProfitPrice)
                {
                    BuyToCover(0, Min(Open, TakeProfitPrice));
                    Print("空头止盈平仓 | 触发价: " + Text(TakeProfitPrice));
                    Return;
                }
            }
        }
        If(isLong > 0)
        {
            If(MarketPosition == -1)
            {
                BuyToCover(0, tradePrice);
                Print("信号反转 | 平空仓");
            }
            If(MarketPosition == 0)
            {
                If(validateStops(True, tradePrice, tradePrice, sl1, tp1, tp2, tp3, StopLossPrice, TakeProfitPrice))
                {
                    Buy(InpLots, tradePrice);
                    Print("买入开仓 | 价格: " + Text(tradePrice) + " | 止损: " + Text(StopLossPrice) + " | 止盈: " + Text(TakeProfitPrice));
                }
            }
        }
        If(isShort > 0)
        {
            If(MarketPosition == 1)
            {
                Sell(0, tradePrice);
                Print("信号反转 | 平多仓");
            }
            If(MarketPosition == 0)
            {
                If(validateStops(False, tradePrice, tradePrice, sl1, tp1, tp2, tp3, StopLossPrice, TakeProfitPrice))
                {
                    SellShort(InpLots, tradePrice);
                    Print("卖出开仓 | 价格: " + Text(tradePrice) + " | 止损: " + Text(StopLossPrice) + " | 止盈: " + Text(TakeProfitPrice));
                }
            }
        }
    }




    OnBarClose(ArrayRef<Integer> indexs)
    {
        //下一个Bar开始前，重新执行当前bar最后一次，参数为当前bar的图层数组
    }
    



    OnTick(TickRef evtTick)
    {
        //Tick更新事件函数，需要SubscribeTick函数订阅后触发，参数evtTick表示更新的tick结构体
        // Print("OnTick收到 - 价格:" + Text(evtTick.last) + " 数量:" + Text(evtTick.volume) + " 品种:" + evtTick.symbol);
    }
    



    OnPosition(PositionRef pos)
    {  
    //持仓更新事件函数，参数pos表示更新的持仓结构体
    }




    OnStrategyPosition(PositionRef pos)
    {
    //策略账户仓更新事件函数，参数pos表示更新的账户仓结构体
        
    }
    
    
    

    OnOrder(OrderRef ord)
    {
        //委托更新事件函数，参数ord表示更新的委托结构体
    }




    OnFill(FillRef ordFill)
    {
        //成交更新事件函数，参数ordFill表示更新的成交结构体
    }




    OnTimer(Integer id,Integer intervalMillsecs)
    {
        //Print("====OnTimer 55： " + Text(id));
    }




    OnEvent(StringRef evtName,MapRef<String,String> evtValue) 
    {
        //通用事件触发函数，参数evtName为事件名称，参数evtValue为事件内容 
    }
    
    
    

    OnExit()
    {
        //当前策略退出时触发
        Print("OnExit......");
    }
