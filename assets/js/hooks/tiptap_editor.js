import { Editor } from '@tiptap/core'
import StarterKit from '@tiptap/starter-kit'
import Image from '@tiptap/extension-image'
import Link from '@tiptap/extension-link'
import Placeholder from '@tiptap/extension-placeholder'

const TiptapEditor = {
  mounted() {
    const textarea = this.el.querySelector('textarea[data-tiptap-target]')
    const editorContainer = this.el.querySelector('[data-tiptap-editor]')

    if (!textarea || !editorContainer) return

    this.editor = new Editor({
      element: editorContainer,
      extensions: [
        StarterKit,
        Image,
        Link.configure({ openOnClick: false }),
        Placeholder.configure({
          placeholder: 'Start writing your post...'
        })
      ],
      content: textarea.value || '',
      editorProps: {
        attributes: {
          class: 'prose prose-sm max-w-none focus:outline-none min-h-[300px] p-4'
        }
      },
      onUpdate: ({ editor }) => {
        textarea.value = editor.getHTML()
        textarea.dispatchEvent(new Event('input', { bubbles: true }))
      }
    })

    this.handleEvent('insert-image', ({ url }) => {
      this.editor.chain().focus().setImage({ src: url }).run()
    })

    this.el.querySelectorAll('[data-tiptap-action]').forEach(button => {
      button.addEventListener('click', (e) => {
        e.preventDefault()
        const action = button.dataset.tiptapAction
        this.handleToolbarAction(action)
      })
    })
  },

  handleToolbarAction(action) {
    const chain = this.editor.chain().focus()

    switch (action) {
      case 'bold': chain.toggleBold().run(); break
      case 'italic': chain.toggleItalic().run(); break
      case 'strike': chain.toggleStrike().run(); break
      case 'code': chain.toggleCode().run(); break
      case 'h2': chain.toggleHeading({ level: 2 }).run(); break
      case 'h3': chain.toggleHeading({ level: 3 }).run(); break
      case 'bullet-list': chain.toggleBulletList().run(); break
      case 'ordered-list': chain.toggleOrderedList().run(); break
      case 'blockquote': chain.toggleBlockquote().run(); break
      case 'code-block': chain.toggleCodeBlock().run(); break
      case 'horizontal-rule': chain.setHorizontalRule().run(); break
      case 'link':
        const url = prompt('Enter URL:')
        if (url) chain.setLink({ href: url }).run()
        break
      case 'undo': chain.undo().run(); break
      case 'redo': chain.redo().run(); break
    }
  },

  destroyed() {
    if (this.editor) this.editor.destroy()
  }
}

export default TiptapEditor
