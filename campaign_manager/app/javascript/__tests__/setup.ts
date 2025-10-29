// Jest setup file for React Testing Library
import '@testing-library/jest-dom'

// Suppress act() warnings that are false positives with @testing-library/user-event v14
// These warnings appear because user-event internally uses act() but React still warns
// See: https://github.com/testing-library/react-testing-library/issues/1051
const originalError = console.error
beforeAll(() => {
  console.error = (...args: any[]) => {
    if (
      typeof args[0] === 'string' &&
      args[0].includes('Warning: An update to') &&
      args[0].includes('inside a test was not wrapped in act(...)')
    ) {
      return
    }
    originalError.call(console, ...args)
  }
})

afterAll(() => {
  console.error = originalError
})

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

// Mock CSRF token meta tag - reset before each test
beforeEach(() => {
  document.head.innerHTML = '<meta name="csrf-token" content="test-token">'
  // Clear fetch mocks
  if (global.fetch && typeof (global.fetch as jest.Mock).mockClear === 'function') {
    (global.fetch as jest.Mock).mockClear()
  }
})

