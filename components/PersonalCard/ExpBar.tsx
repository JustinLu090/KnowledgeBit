'use client'

import React, { useEffect, useState, useRef } from 'react'
import './glassmorphism.css'

interface ExpBarProps {
  exp: number
  expToNext: number
  level: number
  expGained?: number // 新增的 EXP（用於動畫）
}

export default function ExpBar({ exp, expToNext, level, expGained }: ExpBarProps) {
  const [displayExp, setDisplayExp] = useState(exp)
  const [showExpGain, setShowExpGain] = useState(false)
  const [expGainValue, setExpGainValue] = useState(0)
  const containerRef = useRef<HTMLDivElement>(null)

  // 處理 EXP 增加動畫
  useEffect(() => {
    if (expGained && expGained > 0) {
      setExpGainValue(expGained)
      setShowExpGain(true)
      
      // 平滑更新顯示的 EXP
      const startExp = displayExp
      const endExp = exp
      const duration = 500 // 500ms 動畫
      const startTime = Date.now()
      
      const animate = () => {
        const now = Date.now()
        const elapsed = now - startTime
        const progress = Math.min(elapsed / duration, 1)
        
        // 使用 ease-out 緩動函數
        const easeOut = 1 - Math.pow(1 - progress, 3)
        const currentExp = Math.floor(startExp + (endExp - startExp) * easeOut)
        
        setDisplayExp(currentExp)
        
        if (progress < 1) {
          requestAnimationFrame(animate)
        } else {
          setDisplayExp(endExp)
        }
      }
      
      requestAnimationFrame(animate)
      
      // 2 秒後隱藏 +EXP 標籤
      const timer = setTimeout(() => {
        setShowExpGain(false)
      }, 2000)
      
      return () => clearTimeout(timer)
    } else {
      setDisplayExp(exp)
    }
  }, [exp, expGained, displayExp])

  const percentage = expToNext > 0 ? Math.min((displayExp / expToNext) * 100, 100) : 0
  const isNewUser = level === 1 && exp === 0

  return (
    <div ref={containerRef} className="mt-5 space-y-2 relative">
      {/* EXP 數值與進度條 */}
      <div className="flex items-center justify-between gap-3">
        <div className="flex-1 min-w-0">
          <div className="h-2.5 glass-base rounded-full overflow-hidden">
            <div
              className="h-full bg-gradient-to-r from-blue-400/90 via-purple-500/90 to-pink-400/90 rounded-full transition-all duration-500 ease-out backdrop-blur-sm"
              style={{ width: `${percentage}%` }}
            />
          </div>
        </div>
        <div className="glass-text text-xs md:text-sm font-medium whitespace-nowrap flex-shrink-0">
          EXP {displayExp}/{expToNext} ({Math.round(percentage)}%)
        </div>
      </div>

      {/* 新手提示文字 */}
      {isNewUser && (
        <p className="glass-text text-xs text-center opacity-75">
          完成第一場對戰即可獲得 EXP
        </p>
      )}

      {/* +EXP 浮動標籤 */}
      {showExpGain && expGainValue > 0 && (
        <div
          className="absolute left-1/2 -top-8 pointer-events-none z-10 animate-exp-gain"
          style={{
            animation: 'expGainFloat 2s ease-out forwards'
          }}
        >
          <span className="glass-action-button green inline-flex items-center px-3 py-1 rounded-full text-sm font-semibold">
            +{expGainValue} EXP
          </span>
        </div>
      )}

      {/* 動畫樣式 - 使用 style jsx（Next.js）或引入 exp-gain-animation.css */}
      <style jsx>{`
        @keyframes expGainFloat {
          0% {
            opacity: 1;
            transform: translate(-50%, 0);
          }
          50% {
            opacity: 1;
            transform: translate(-50%, -1rem);
          }
          100% {
            opacity: 0;
            transform: translate(-50%, -2rem);
          }
        }
        .animate-exp-gain {
          animation: expGainFloat 2s ease-out forwards;
        }
      `}</style>
    </div>
  )
}
