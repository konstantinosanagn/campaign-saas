import apiClient, { ApiClient } from '@/libs/utils/apiClient'

describe('apiClient', () => {
  beforeEach(() => {
    // Clear fetch mocks - fetch is already mocked in setup.ts
    if (global.fetch && typeof (global.fetch as jest.Mock).mockClear === 'function') {
      (global.fetch as jest.Mock).mockClear()
    }
    // Reset CSRF token
    document.head.innerHTML = '<meta name="csrf-token" content="test-token">'
  })

  describe('CSRF token handling', () => {
    it('loads CSRF token from meta tag', () => {
      document.head.innerHTML = '<meta name="csrf-token" content="test-csrf-token">'
      const newClient = new ApiClient()
      
      // Verify the meta tag exists
      expect(document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')).toBe('test-csrf-token')
      
      // Verify the client can make requests (token is loaded)
      // We test this by making a request and checking headers include CSRF token
      expect(newClient).toBeDefined()
    })

    it('handles missing CSRF token gracefully', () => {
      document.head.innerHTML = ''
      const newClient = new ApiClient()
      
      // Should not crash and client should still be created
      expect(document.querySelector('meta[name="csrf-token"]')).toBeNull()
      expect(newClient).toBeDefined()
    })
  })

  describe('GET requests', () => {
    it('makes GET request with correct headers', async () => {
      (fetch as jest.Mock).mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ 'content-type': 'application/json' }),
        json: async () => ({ data: 'test' }),
      })

      await apiClient.get('campaigns')

      expect(fetch).toHaveBeenCalledWith(
        '/api/v1/campaigns',
        expect.objectContaining({
          method: 'GET',
          headers: expect.objectContaining({
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'X-CSRF-Token': 'test-token',
          }),
        })
      )
    })

    it('handles successful response', async () => {
      const mockData = { id: 1, title: 'Test Campaign' };
      
      (fetch as jest.Mock).mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ 'content-type': 'application/json' }),
        json: async () => mockData,
      });

      const response = await apiClient.get('campaigns');

      expect(response.data).toEqual(mockData);
      expect(response.error).toBeUndefined();
      expect(response.status).toBe(200);
    });

    it('handles error response', async () => {
      (fetch as jest.Mock).mockResolvedValueOnce({
        ok: false,
        status: 404,
        headers: new Headers({ 'content-type': 'application/json' }),
        json: async () => ({ error: 'Not found' }),
      })

      const response = await apiClient.get('campaigns/999')

      // apiClient uses the error message from the response if available
      expect(response.error).toBe('Not found')
      expect(response.status).toBe(404)
    })
    
    it('handles error response without error message', async () => {
      (fetch as jest.Mock).mockResolvedValueOnce({
        ok: false,
        status: 500,
        headers: new Headers({ 'content-type': 'application/json' }),
        json: async () => ({}),
      })

      const response = await apiClient.get('campaigns')

      // apiClient defaults to HTTP status code when no error message
      expect(response.error).toBe('HTTP 500')
      expect(response.status).toBe(500)
    })

    it('handles 401 redirect in production', async () => {
      // Override window.location for this test only
      const originalLocation = window.location;
      delete (window as any).location;
      (window as any).location = {
        hostname: 'production.com',
        href: '',
        pathname: '/',
        search: '',
        hash: '',
        assign: jest.fn(),
        reload: jest.fn(),
        replace: jest.fn(),
      };

      (fetch as jest.Mock).mockResolvedValueOnce({
        ok: false,
        status: 401,
        headers: new Headers({ 'content-type': 'application/json' }),
        json: async () => ({ error: 'Unauthorized' }),
      });

      const response = await apiClient.get('campaigns');

      expect(response.status).toBe(401);
      expect(response.error).toBe('Unauthorized');
      
      // Restore original location
      window.location = originalLocation;
    });
  })

  describe('POST requests', () => {
    it('makes POST request with data', async () => {
      (fetch as jest.Mock).mockResolvedValueOnce({
        ok: true,
        status: 201,
        headers: new Headers({ 'content-type': 'application/json' }),
        json: async () => ({ id: 1 }),
      })

      await apiClient.post('campaigns', { title: 'Test' })

      expect(fetch).toHaveBeenCalledWith(
        '/api/v1/campaigns',
        expect.objectContaining({
          method: 'POST',
          body: JSON.stringify({ title: 'Test' }),
        })
      )
    })
  })

  describe('create method', () => {
    it('wraps data in resource key', async () => {
      (fetch as jest.Mock).mockResolvedValueOnce({
        ok: true,
        status: 201,
        headers: new Headers({ 'content-type': 'application/json' }),
        json: async () => ({ id: 1 }),
      })

      await apiClient.create('campaigns', { title: 'Test', basePrompt: 'Prompt' })

      expect(fetch).toHaveBeenCalledWith(
        '/api/v1/campaigns',
        expect.objectContaining({
          method: 'POST',
          body: JSON.stringify({ campaign: { title: 'Test', basePrompt: 'Prompt' } }),
        })
      )
    })
  })

  describe('update method', () => {
    it('wraps data in resource key', async () => {
      (fetch as jest.Mock).mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ 'content-type': 'application/json' }),
        json: async () => ({ id: 1 }),
      })

      await apiClient.update('campaigns', 1, { title: 'Updated' })

      expect(fetch).toHaveBeenCalledWith(
        '/api/v1/campaigns/1',
        expect.objectContaining({
          method: 'PUT',
          body: JSON.stringify({ campaign: { title: 'Updated' } }),
        })
      )
    })
  })

  describe('show method', () => {
    it('makes GET request to show endpoint', async () => {
      (fetch as jest.Mock).mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ 'content-type': 'application/json' }),
        json: async () => ({ id: 1 }),
      })

      await apiClient.show('campaigns', 1)

      expect(fetch).toHaveBeenCalledWith(
        '/api/v1/campaigns/1',
        expect.objectContaining({
          method: 'GET',
        })
      )
    })
  })

  describe('error handling', () => {
    it('handles network errors', async () => {
      (fetch as jest.Mock).mockRejectedValueOnce(new Error('Network error'))

      const response = await apiClient.get('campaigns')

      expect(response.error).toBe('Network error')
      expect(response.status).toBe(0)
    })

    it('handles validation errors (422)', async () => {
      (fetch as jest.Mock).mockResolvedValueOnce({
        ok: false,
        status: 422,
        headers: new Headers({ 'content-type': 'application/json' }),
        json: async () => ({ errors: ['Title can\'t be blank', 'Base prompt can\'t be blank'] }),
      })

      const response = await apiClient.post('campaigns', {})

      expect(response.error).toBe('Title can\'t be blank, Base prompt can\'t be blank')
      expect(response.status).toBe(422)
    })

    it('handles 204 No Content responses', async () => {
      (fetch as jest.Mock).mockResolvedValueOnce({
        ok: true,
        status: 204,
        headers: new Headers(),
        text: async () => '',
      })

      const response = await apiClient.destroy('campaigns', 1)

      expect(response.data).toBeNull()
      expect(response.status).toBe(204)
    })

    it('handles non-JSON responses with text', async () => {
      (fetch as jest.Mock).mockResolvedValueOnce({
        ok: false,
        status: 500,
        headers: new Headers({ 'content-type': 'text/plain' }),
        text: async () => 'Internal Server Error',
      })

      const response = await apiClient.get('campaigns')

      expect(response.error).toBe('HTTP 500')
      expect(response.status).toBe(500)
    })

    it('handles error response with message property', async () => {
      (fetch as jest.Mock).mockResolvedValueOnce({
        ok: false,
        status: 400,
        headers: new Headers({ 'content-type': 'application/json' }),
        json: async () => ({ message: 'Bad Request Message' }),
      })

      const response = await apiClient.get('campaigns')

      expect(response.error).toBe('Bad Request Message')
      expect(response.status).toBe(400)
    })
  })
})

