/* GSWindowTabBarLayout.m: how wide the tab bar's tabs are.

   Copyright (C) 2026 Daniel Boyd

   Author: Daniel Boyd <danieljboyd@icloud.com>
   Date: 2026

   This file is part of the GNUstep GUI Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; see the file COPYING.LIB.
   If not, see <http://www.gnu.org/licenses/> or write to the
   Free Software Foundation, 51 Franklin Street, Fifth Floor,
   Boston, MA 02110-1301, USA.
*/

/* Upstream this function goes into GSWindowTabBarView.m; it is apart
   here so the display-free tests can compile it in without the view. */

#import "GSWindowTabBarView.h"

CGFloat
GSWindowTabWidth(NSUInteger count, CGFloat width,
                 CGFloat minimum, CGFloat maximum)
{
  CGFloat each;

  if (count == 0)
    {
      return 0.0;
    }
  each = floor(width / count);
  if (maximum > 0.0 && each > maximum)
    {
      each = maximum;
    }
  if (each < minimum)
    {
      each = minimum;
    }
  return each;
}
