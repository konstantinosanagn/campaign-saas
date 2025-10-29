import React from 'react'

export default function PlaceholderRoot(props: { message?: string }) {
  return (
    <div className="p-6 text-center text-gray-700">
      {props.message || 'Placeholder component loaded'}
    </div>
  )
}


