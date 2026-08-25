'use client'

import { useQuery } from '@tanstack/react-query'
import {
  getIndustriesAction,
  getCategoriesAction,
  getCommoditiesAction,
  getStatesAction,
  getDistrictsAction,
  getGradesAction,
  getUnitsAction
} from '@/src/server/actions/master-data-actions'

export function useIndustries() {
  return useQuery({
    queryKey: ['masterData', 'industries'],
    queryFn: async () => {
      const res = await getIndustriesAction()
      if (!res.success) throw new Error(res.error)
      return res.data
    },
  })
}

export function useCategories() {
  return useQuery({
    queryKey: ['masterData', 'categories'],
    queryFn: async () => {
      const res = await getCategoriesAction()
      if (!res.success) throw new Error(res.error)
      return res.data
    },
  })
}

export function useCommodities(categoryId?: string) {
  return useQuery({
    queryKey: ['masterData', 'commodities', categoryId || 'all'],
    queryFn: async () => {
      const res = await getCommoditiesAction()
      if (!res.success) throw new Error(res.error)
      if (categoryId) {
        return (res.data || []).filter((c: any) => c.categoryId === categoryId)
      }
      return res.data || []
    },
  })
}

export function useStates() {
  return useQuery({
    queryKey: ['masterData', 'states'],
    queryFn: async () => {
      const res = await getStatesAction()
      if (!res.success) throw new Error(res.error)
      return res.data
    },
  })
}

export function useDistricts() {
  return useQuery({
    queryKey: ['masterData', 'districts'],
    queryFn: async () => {
      const res = await getDistrictsAction()
      if (!res.success) throw new Error(res.error)
      return res.data
    },
  })
}

export function useGrades() {
  return useQuery({
    queryKey: ['masterData', 'grades'],
    queryFn: async () => {
      const res = await getGradesAction()
      if (!res.success) throw new Error(res.error)
      return res.data
    },
  })
}

export function useUnits() {
  return useQuery({
    queryKey: ['masterData', 'units'],
    queryFn: async () => {
      const res = await getUnitsAction()
      if (!res.success) throw new Error(res.error)
      return res.data
    },
  })
}
