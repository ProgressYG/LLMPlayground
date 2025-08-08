module.exports = {
  darkMode: 'class',
  content: [
    './app/views/**/*.html.erb',
    './app/helpers/**/*.rb',
    './app/assets/stylesheets/**/*.css',
    './app/javascript/**/*.js'
  ],
  theme: {
    extend: {
      colors: {
        // Background colors
        'primary': '#0F172A',     // slate-900
        'secondary': '#1E293B',    // slate-800
        'card': '#334155',         // slate-700
        'hover': '#475569',        // slate-600
        
        // Text colors  
        'muted': '#64748B',        // slate-500
        'label': '#94A3B8',        // slate-400
        
        // Border colors
        'default': '#475569',      // slate-600
        'focus': '#3B82F6',        // blue-500
        
        // Accent colors
        'accent': {
          'primary': '#3B82F6',    // blue-500
          'success': '#10B981',    // emerald-500
          'warning': '#F59E0B',    // amber-500
          'error': '#EF4444',      // red-500
          'info': '#06B6D4',       // cyan-500
        },
      },
      textColor: {
        'primary': '#F1F5F9',      // slate-100
        'secondary': '#CBD5E1',    // slate-300
        'muted': '#64748B',        // slate-500
        'label': '#94A3B8',        // slate-400
      },
      backgroundColor: {
        'primary': '#0F172A',      // slate-900
        'secondary': '#1E293B',     // slate-800
        'card': '#334155',         // slate-700
        'hover': '#475569',        // slate-600
      },
      borderColor: {
        'default': '#475569',      // slate-600
        'focus': '#3B82F6',        // blue-500
        'hover': '#64748B',        // slate-500
      },
      gridTemplateColumns: {
        // 70:30 layout
        'layout': '70fr 30fr',
      },
      animation: {
        'pulse-slow': 'pulse 3s cubic-bezier(0.4, 0, 0.6, 1) infinite',
      },
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/typography'),
  ],
}