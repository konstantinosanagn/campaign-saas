'use client'

import { Campaign } from '@/types'

interface CampaignSidebarProps {
  campaigns: Campaign[]
  selectedCampaign: number | null
  onCampaignClick: (index: number) => void
  onCreateClick: () => void
  onEditClick: (index: number) => void
  onDeleteClick: (index: number) => void
}

export default function CampaignSidebar({
  campaigns,
  selectedCampaign,
  onCampaignClick,
  onCreateClick,
  onEditClick,
  onDeleteClick,
}: CampaignSidebarProps) {
  return (
    <div className="col-span-3 bg-transparent border-r border-gray-200">
      <div className="p-4 py-4">
        <div className="flex items-center justify-between">
          <h3 className="text-sm sm:text-lg md:text-xl lg:text-2xl xl:text-3xl font-semibold text-gray-900">
            Campaigns
          </h3>
          <svg
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 24 24"
            strokeWidth="2.5"
            stroke="#004dff"
            className="size-6 hover:stroke-white hover:bg-[#004dff] active:stroke-[#004dff] active:bg-transparent active:border active:border-[#004dff] rounded p-1 transition-colors duration-200 cursor-pointer"
            onClick={onCreateClick}
          >
            <path strokeLinecap="round" strokeLinejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
          </svg>
        </div>
      </div>

      <div className="p-4 py-4">
        {campaigns.length === 0 ? (
          <p className="text-sm text-gray-600">
            Click <span className="text-[#004dff] font-bold">+</span> to create a campaign.
          </p>
        ) : (
          <div className="space-y-2">
            {campaigns.map((campaign, index) => (
              <div
                key={index}
                onClick={() => onCampaignClick(index)}
                className={`p-2 rounded-lg border transition-all duration-300 cursor-pointer group ${
                  selectedCampaign === index
                    ? 'bg-blue-50 border-blue-200 hover:bg-blue-100'
                    : 'bg-gray-50 border-gray-200 hover:bg-white hover:shadow-md hover:border-gray-300'
                }`}
              >
                <div className="flex items-center justify-between mb-1">
                  <h4
                    className="text-sm font-medium text-gray-900 group-hover:text-[#004dff] transition-colors duration-300 flex-1 min-w-0 mr-2 truncate"
                    title={campaign.title}
                  >
                    {campaign.title}
                  </h4>
                  <div className="flex space-x-1 flex-shrink-0">
                    <button
                      className="p-1 text-gray-400 hover:text-gray-600 transition-colors duration-200"
                      onClick={(e) => {
                        e.stopPropagation()
                        onEditClick(index)
                      }}
                    >
                      <svg
                        xmlns="http://www.w3.org/2000/svg"
                        fill="none"
                        viewBox="0 0 24 24"
                        strokeWidth="1.5"
                        stroke="currentColor"
                        className="size-4"
                      >
                        <path
                          strokeLinecap="round"
                          strokeLinejoin="round"
                          d="m16.862 4.487 1.687-1.688a1.875 1.875 0 1 1 2.652 2.652L6.832 19.82a4.5 4.5 0 0 1-1.897 1.13l-2.685.8.8-2.685a4.5 4.5 0 0 1 1.13-1.897L16.863 4.487Zm0 0L19.5 7.125"
                        />
                      </svg>
                    </button>
                    <button
                      className="p-1 text-gray-400 hover:text-red-500 transition-colors duration-200"
                      onClick={(e) => {
                        e.stopPropagation()
                        onDeleteClick(index)
                      }}
                    >
                      <svg
                        xmlns="http://www.w3.org/2000/svg"
                        fill="none"
                        viewBox="0 0 24 24"
                        strokeWidth="1.5"
                        stroke="currentColor"
                        className="size-4"
                      >
                        <path
                          strokeLinecap="round"
                          strokeLinejoin="round"
                          d="m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0"
                        />
                      </svg>
                    </button>
                  </div>
                </div>
                <p className="text-xs text-gray-500 mt-1 break-words overflow-hidden">
                  {campaign.basePrompt && campaign.basePrompt.substring(0, 50)}...
                </p>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}


