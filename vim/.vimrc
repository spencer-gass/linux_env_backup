" General Settings
""set number                 " Show line numbers
set showmatch              " Highlight matching parentheses
set hlsearch               " Highlight search results
set incsearch              " Incremental search
set ignorecase             " Ignore case when searching
set smartcase              " Override ignorecase if search contains uppercase
set nowrap                 " Disable line wrapping
set tabstop=4              " Number of spaces that a <Tab> in the file counts for
set softtabstop=4          " Number of spaces used for each step of (auto)indent
set shiftwidth=4           " Number of spaces used for autoindent
set expandtab              " Insert spaces instead of <Tab>

" Syntax Highlighting
syntax on

" Enable Mouse Support
set mouse=a

" Enable 256-color Terminal Support
set t_Co=256

" Indentation
set autoindent             " Automatically indent new lines
set smartindent            " Smart autoindenting for C-like languages

" Key Mappings (Add your custom key mappings here)
nnoremap <leader>w :w!<CR>  
nnoremap <leader>q :qa!<CR>
nnoremap <leader>a :wqa!<CR>

nnoremap <leader>n :noh<CR>

" Color Scheme (Add your preferred color scheme here)
" colorscheme desert
colorscheme industry

set clipboard=unnamedplus

