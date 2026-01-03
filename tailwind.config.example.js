/**
 * Tailwind CSS 配置範例
 * 
 * 如果要在 Tailwind 中定義自訂動畫，可以將以下內容加入 tailwind.config.js
 */

module.exports = {
  content: [
    './components/**/*.{js,ts,jsx,tsx}',
    './app/**/*.{js,ts,jsx,tsx}',
    './pages/**/*.{js,ts,jsx,tsx}',
  ],
  theme: {
    extend: {
      // 自訂動畫（可選）
      keyframes: {
        'exp-gain-float': {
          '0%': {
            opacity: '1',
            transform: 'translate(-50%, 0)',
          },
          '50%': {
            opacity: '1',
            transform: 'translate(-50%, -1rem)',
          },
          '100%': {
            opacity: '0',
            transform: 'translate(-50%, -2rem)',
          },
        },
      },
      animation: {
        'exp-gain': 'expGainFloat 2s ease-out forwards',
      },
    },
  },
  plugins: [],
}
