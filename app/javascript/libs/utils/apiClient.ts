// API Client for Rails API communication
// Handles CSRF tokens, error handling, and response formatting

interface ApiResponse<T = unknown> {
  data?: T
  error?: string
  status: number
}

interface ApiError {
  message: string
  status: number
  details?: unknown
}

class ApiClient {
  private baseURL: string
  private csrfToken: string | null

  constructor(baseURL: string = '/api/v1') {
    this.baseURL = baseURL
    this.csrfToken = null
    this.loadCSRFToken()
  }

  private loadCSRFToken(): void {
    const metaTag = document.querySelector('meta[name="csrf-token"]') as HTMLMetaElement
    this.csrfToken = metaTag && metaTag.content ? metaTag.content : null
  }

  private async request<T>(
    endpoint: string,
    options: RequestInit = {}
  ): Promise<ApiResponse<T>> {
    try {
      // Ensure CSRF token is fresh
      this.loadCSRFToken()

      const url = `${this.baseURL}/${endpoint}`.replace(/\/+/g, '/')
      const config: RequestInit = {
        ...options,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          ...(this.csrfToken && { 'X-CSRF-Token': this.csrfToken }),
          ...(options.headers || {}),
        },
      }

      if (config.body && typeof config.body === 'object') {
        config.body = JSON.stringify(config.body)
      }
      console.log('📦 [API Request]', {
        url,
        method: config.method,
        body: config.body,
        headers: config.headers,
      })
      
      const response = await fetch(url, config)
      
      // Handle different response types
      let data: unknown = null
      const contentType = response.headers?.get('content-type')
      
      if (contentType && contentType.includes('application/json')) {
        data = await response.json()
      } else if (response.status === 204) {
        // No content response
        data = null
      } else {
        data = await response.text()
      }

      if (!response.ok) {
        // Handle 401 Unauthorized - redirect to login (only in production)
        // In development, auth is skipped so 401s shouldn't happen
        if (response.status === 401 && window.location.hostname !== 'localhost' && window.location.hostname !== '127.0.0.1') {
          // Redirect to Devise login page only in production
          window.location.href = '/users/sign_in'
          return {
            error: 'Unauthorized',
            status: 401,
            data: data
          }
        }
        
        // Handle validation errors (422) - Rails returns { errors: [...] }
        let errorMessage = `HTTP ${response.status}`
        if (data && typeof data === 'object' && 'errors' in data && Array.isArray((data as Record<string, unknown>).errors)) {
          errorMessage = ((data as { errors: string[] }).errors).join(', ')
        } else if (data && typeof data === 'object' && 'error' in data && typeof (data as Record<string, unknown>).error === 'string') {
          errorMessage = (data as { error: string }).error
        } else if (data && typeof data === 'object' && 'message' in data && typeof (data as Record<string, unknown>).message === 'string') {
          errorMessage = (data as { message: string }).message
        }
        
        return {
          error: errorMessage,
          status: response.status,
          data
        }
      }

      return {
        data: data as T,
        status: response.status
      }
    } catch (error) {
      console.error('API Request failed:', error)
      return {
        error: error instanceof Error ? error.message : 'Network error',
        status: 0
      }
    }
  }

  // HTTP Methods
  async get<T>(endpoint: string): Promise<ApiResponse<T>> {
    return this.request<T>(endpoint, { method: 'GET' })
  }

  async post<T>(endpoint: string, data?: unknown): Promise<ApiResponse<T>> {
    return this.request<T>(endpoint, {
      method: 'POST',
      body: data ? JSON.stringify(data) : undefined,
    })
  }

  async put<T>(endpoint: string, data?: unknown): Promise<ApiResponse<T>> {
    return this.request<T>(endpoint, {
      method: 'PUT',
      body: data ? JSON.stringify(data) : undefined,
    })
  }

  async delete<T>(endpoint: string): Promise<ApiResponse<T>> {
    return this.request<T>(endpoint, { method: 'DELETE' })
  }

  // Convenience methods for common operations
  async create<T>(resource: string, data: unknown): Promise<ApiResponse<T>> {
    // Rails expects nested data: { campaign: {...} } or { lead: {...} }
    const resourceKey = resource.slice(0, -1) // Remove 's' from 'campaigns' -> 'campaign'
    const wrappedData = { [resourceKey]: data }
    return this.post<T>(`/${resource}`, wrappedData)
  }

  async update<T>(resource: string, id: number | string, data: unknown): Promise<ApiResponse<T>> {
    // Rails expects nested data: { campaign: {...} } or { lead: {...} }
    const resourceKey = resource.slice(0, -1) // Remove 's' from 'campaigns' -> 'campaign'
    const wrappedData = { [resourceKey]: data }
    return this.put<T>(`/${resource}/${id}`, wrappedData)
  }

  async destroy<T>(resource: string, id: number | string): Promise<ApiResponse<T>> {
    return this.delete<T>(`/${resource}/${id}`)
  }

  async index<T>(resource: string): Promise<ApiResponse<T>> {
    return this.get<T>(`/${resource}`)
  }

  async show<T>(resource: string, id: number | string): Promise<ApiResponse<T>> {
    return this.get<T>(`/${resource}/${id}`)
  }
}

// Create singleton instance
const apiClient = new ApiClient()

export default apiClient
export { ApiClient, type ApiResponse, type ApiError }
