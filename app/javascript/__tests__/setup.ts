// Jest setup file for React Testing Library
import '@testing-library/jest-dom'

// Mock window.matchMedia (required by some UI libraries)
Object.defineProperty(window, 'matchMedia', {
  writable: true,
  value: jest.fn().mockImplementation(query => ({
    matches: false,
    media: query,
    onchange: null,
    addListener: jest.fn(), // deprecated
    removeListener: jest.fn(), // deprecated
    addEventListener: jest.fn(),
    removeEventListener: jest.fn(),
    dispatchEvent: jest.fn(),
  })),
})

// Mock window.confirm
window.confirm = jest.fn(() => true)

// Mock window.location
Object.defineProperty(window, 'location', {
  writable: true,
  configurable: true,
  value: {
    hostname: 'localhost',
    href: '',
    pathname: '/',
    search: '',
    hash: '',
    assign: jest.fn(),
    reload: jest.fn(),
    replace: jest.fn(),
  },
});

// Mock fetch globally
global.fetch = jest.fn()

// Polyfill File.text() for jsdom (if not available)
// Store file content in a WeakMap so we can retrieve it
const fileContentMap = new WeakMap<Blob, string>()

// Patch Blob/File to store text content
const OriginalBlob = global.Blob
global.Blob = class Blob extends OriginalBlob {
  constructor(blobParts?: BlobPart[], options?: BlobPropertyBag) {
    super(blobParts, options)
    if (blobParts) {
      const textParts = blobParts
        .filter(part => typeof part === 'string')
        .map(part => part as string)
      if (textParts.length > 0) {
        fileContentMap.set(this, textParts.join(''))
      }
    }
  }
} as any

if (typeof File !== 'undefined') {
  const OriginalFile = global.File
  global.File = class File extends OriginalFile {
    constructor(fileBits: BlobPart[], fileName: string, options?: FilePropertyBag) {
      super(fileBits, fileName, options)
      const textParts = fileBits
        .filter(part => typeof part === 'string')
        .map(part => part as string)
      if (textParts.length > 0) {
        fileContentMap.set(this, textParts.join(''))
      }
    }
  } as any
  
  if (!File.prototype.text) {
    File.prototype.text = function(this: File) {
      const content = fileContentMap.get(this) || ''
      return Promise.resolve(content)
    }
  }
}

// Mock hooks that make API calls
jest.mock('@/hooks/useAgentConfigs', () => ({
  useAgentConfigs: () => ({
    configs: [],
    loading: false,
    error: null,
    loadConfigs: jest.fn(),
    createConfig: jest.fn(),
    updateConfig: jest.fn()
  })
}))

jest.mock('@/hooks/useAgentExecution', () => ({
  useAgentExecution: () => ({
    loading: false,
    runAgentsForLead: jest.fn(),
    runAgentsForMultipleLeads: jest.fn()
  })
}))

jest.mock('@/hooks/useAgentOutputs', () => ({
  useAgentOutputs: () => ({
    loading: false,
    outputs: [],
    loadAgentOutputs: jest.fn()
  })
}))

// Mock CSRF token meta tag - reset before each test
beforeEach(() => {
  document.head.innerHTML = '<meta name="csrf-token" content="test-token">'
  // Clear fetch mocks
  if (global.fetch && typeof (global.fetch as jest.Mock).mockClear === 'function') {
    (global.fetch as jest.Mock).mockClear()
  }
})

