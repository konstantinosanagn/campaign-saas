import '@/styles/cube.css'

interface CubeProps {
  variant?: 'blue' | 'black'
  size?: 'small' | 'default'
}

export default function Cube({ variant = 'blue', size = 'default' }: CubeProps) {
  return (
    <div className={`cube-spinner ${variant === 'black' ? 'cube-spinner-black' : ''} ${size === 'small' ? 'cube-spinner-small' : ''}`}>
      <div></div>
      <div></div>
      <div></div>
      <div></div>
      <div></div>
      <div></div>
    </div>
  )
}


