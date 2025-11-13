import React, { useEffect, useState } from 'react';

interface TypewriterTextProps {
  words: string[];
}

const TypewriterText: React.FC<TypewriterTextProps> = ({ words }) => {
  const [index, setIndex] = useState(0);
  const [subIndex, setSubIndex] = useState(0);
  const [deleting, setDeleting] = useState(false);

  useEffect(() => {
    if (!words.length) return;

    const current = words[index % words.length];

    // Typing speed
    const baseDelay = deleting ? 40 : 80;

    const handler = setTimeout(() => {
      if (!deleting && subIndex === current.length) {
        setDeleting(true);
        return;
      }

      if (deleting && subIndex === 0) {
        setDeleting(false);
        setIndex((prev) => (prev + 1) % words.length);
        return;
      }

      setSubIndex((prev) => prev + (deleting ? -1 : 1));
    }, baseDelay);

    return () => clearTimeout(handler);
  }, [subIndex, deleting, index, words]);

  return (
    <span className="border-r border-[#004dff] pr-1 animate-pulse">
      {words[index % words.length].substring(0, subIndex)}
    </span>
  );
};

export default TypewriterText;

